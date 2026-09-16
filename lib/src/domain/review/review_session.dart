// Copyright (C) 2024 ChessSRS contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:chess_srs/src/domain/chapter.dart';
import 'package:chess_srs/src/domain/clock.dart';
import 'package:chess_srs/src/domain/repertoire_decision.dart';
import 'package:chess_srs/src/domain/repertoire_move.dart';
import 'package:chess_srs/src/domain/repertoire_node.dart';
import 'package:chess_srs/src/domain/review/review_prompt.dart';
import 'package:chess_srs/src/domain/review/review_scope.dart';
import 'package:chess_srs/src/domain/review/review_step_result.dart';
import 'package:chess_srs/src/domain/review_result.dart';
import 'package:chess_srs/src/domain/review_state.dart';
import 'package:chess_srs/src/domain/scheduler.dart';
import 'package:chess_srs/src/domain/study.dart';
import 'package:dartchess/dartchess.dart';

/// Active review session state machine.
///
/// Encapsulates queue management, move validation against repertoire (Invariant §2.1),
/// auto-traversal through opponent replies and already-learned user moves (Invariant §2.4),
/// and deterministic time testing via [Clock] (Invariant §3.2).
class ReviewSession {
  ReviewSession({
    required List<Study> studies,
    required List<Chapter> chapters,
    required List<RepertoireDecision> decisions,
    required Map<String, ReviewState> reviewStates,
    this.scope = const ReviewScope.all(),
    this.scheduler = const SimpleScheduler(),
    this.clock = const SystemClock(),
  }) : _studies = {for (final s in studies) s.id: s},
       _chapters = {for (final c in chapters) c.id: c},
       _reviewStates = Map<String, ReviewState>.from(reviewStates),
       _decisionForNode = {for (final d in decisions) d.nodeId: d} {
    // Index all nodes across chapter trees for O(1) lookup
    for (final chapter in chapters) {
      if (chapter.root != null) {
        _indexNodes(chapter.root!);
      }
    }

    // Build initial due queue
    final now = clock.now();
    for (final d in decisions) {
      if (!scope.matches(studyId: d.studyId, chapterId: d.chapterId)) {
        continue;
      }
      final state = _reviewStates[d.id];
      if (state == null || state.isDueAt(now)) {
        _dueQueue.add(d);
      }
    }

    _initialDueCount = _dueQueue.length;
    _advanceToNextDue();
  }

  final ReviewScope scope;
  final Scheduler scheduler;
  final Clock clock;

  final Map<String, Study> _studies;
  final Map<String, Chapter> _chapters;
  final Map<String, ReviewState> _reviewStates;
  final Map<String, RepertoireDecision> _decisionForNode;
  final Map<String, RepertoireNode> _nodesById = {};

  final List<RepertoireDecision> _dueQueue = [];
  ReviewPrompt? _currentPrompt;
  int _completedCount = 0;
  late final int _initialDueCount;

  // ---------------------------------------------------------------------------
  // Getters
  // ---------------------------------------------------------------------------

  ReviewPrompt? get currentPrompt => _currentPrompt;
  int get remainingDueCount => _dueQueue.length + (_currentPrompt != null ? 1 : 0);
  int get completedCount => _completedCount;
  int get initialDueCount => _initialDueCount;
  bool get isComplete => _currentPrompt == null && _dueQueue.isEmpty;
  Map<String, ReviewState> get reviewStates => Map.unmodifiable(_reviewStates);

  // ---------------------------------------------------------------------------
  // Session Actions
  // ---------------------------------------------------------------------------

  /// Submit a user move to validate against the expected repertoire continuation.
  ReviewStepResult submitMove({required String from, required String to, String? promotion}) {
    final prompt = _currentPrompt;
    if (prompt == null) {
      throw StateError('Cannot submit move: review session has no active prompt');
    }

    final decision = prompt.decision;
    final prevState = _reviewStates[decision.id] ?? ReviewState.initial(decisionId: decision.id);

    // Validate move against expected repertoire moves (Invariant §2.1)
    final expectedMatch = prompt.expectedMoves.where((exp) {
      final matchSquares =
          exp.from.toLowerCase() == from.toLowerCase() && exp.to.toLowerCase() == to.toLowerCase();
      if (!matchSquares) return false;
      if (promotion != null && exp.promotion != null) {
        return exp.promotion!.toLowerCase() == promotion.toLowerCase();
      }
      return true;
    }).firstOrNull;

    final now = clock.now();

    if (expectedMatch != null) {
      // -----------------------------------------------------------------------
      // CORRECT MOVE
      // -----------------------------------------------------------------------
      final nextState = scheduler.schedule(
        previous: prevState,
        result: ReviewResult.correct,
        now: now,
      );
      _reviewStates[decision.id] = nextState;

      final event = ReviewEvent(
        decisionId: decision.id,
        when: now,
        result: ReviewResult.correct,
        oldState: prevState,
        newState: nextState,
      );

      _completedCount++;

      return _continueWithCorrectMove(
        prompt: prompt,
        expectedMatch: expectedMatch,
        updatedState: nextState,
        event: event,
      );
    } else {
      // -----------------------------------------------------------------------
      // INCORRECT MOVE
      // -----------------------------------------------------------------------
      final movePlayed = RepertoireMove(from: from, to: to, promotion: promotion);

      final nextState = scheduler.schedule(
        previous: prevState,
        result: ReviewResult.incorrect,
        now: now,
      );
      _reviewStates[decision.id] = nextState;

      final event = ReviewEvent(
        decisionId: decision.id,
        when: now,
        result: ReviewResult.incorrect,
        oldState: prevState,
        newState: nextState,
      );

      // Re-queue the failed decision at the end of the session queue
      // so the user can re-test it before completing the session
      _dueQueue.removeWhere((d) => d.id == decision.id);
      _dueQueue.add(decision);

      return ReviewStepResult(
        isCorrect: false,
        movePlayed: movePlayed,
        expectedMoves: prompt.expectedMoves,
        updatedState: nextState,
        event: event,
        autoPlayedMoves: const [],
        nextPrompt: _currentPrompt, // keeps prompt until user continues or retries
        sessionComplete: false,
      );
    }
  }

  /// Retry a move on the current prompt after an incorrect answer.
  ///
  /// If the retry is correct, advances along the repertoire line without
  /// overwriting the initial lapse recorded in SRS.
  ReviewStepResult retryMove({required String from, required String to, String? promotion}) {
    final prompt = _currentPrompt;
    if (prompt == null) {
      throw StateError('Cannot retry move: review session has no active prompt');
    }

    final expectedMatch = prompt.expectedMoves.where((exp) {
      final matchSquares =
          exp.from.toLowerCase() == from.toLowerCase() && exp.to.toLowerCase() == to.toLowerCase();
      if (!matchSquares) return false;
      if (promotion != null && exp.promotion != null) {
        return exp.promotion!.toLowerCase() == promotion.toLowerCase();
      }
      return true;
    }).firstOrNull;

    final currentState =
        _reviewStates[prompt.decision.id] ?? ReviewState.initial(decisionId: prompt.decision.id);

    if (expectedMatch != null) {
      return _continueWithCorrectMove(
        prompt: prompt,
        expectedMatch: expectedMatch,
        updatedState: currentState,
        event: null,
      );
    } else {
      final movePlayed = RepertoireMove(from: from, to: to, promotion: promotion);
      return ReviewStepResult(
        isCorrect: false,
        movePlayed: movePlayed,
        expectedMoves: prompt.expectedMoves,
        updatedState: currentState,
        event: null,
        autoPlayedMoves: const [],
        nextPrompt: _currentPrompt,
        sessionComplete: false,
      );
    }
  }

  ReviewStepResult _continueWithCorrectMove({
    required ReviewPrompt prompt,
    required RepertoireMove expectedMatch,
    required ReviewState updatedState,
    required ReviewEvent? event,
  }) {
    final now = clock.now();
    final autoPlayed = <AutoPlayedMove>[];
    var activeNode = _findChildForMove(prompt.currentNode, expectedMatch);

    while (activeNode != null) {
      if (activeNode.children.isEmpty) {
        activeNode = null;
        break;
      }

      // Opponent turn: first child represents opponent continuation
      final opponentChild = activeNode.children.first;
      final opponentMove = opponentChild.incomingMove!;
      autoPlayed.add(
        AutoPlayedMove(
          move: opponentMove,
          fenBefore: activeNode.fen,
          fenAfter: opponentChild.fen,
          isUserMove: false,
          comment: opponentChild.comment,
        ),
      );

      // Now at opponentChild, which is user's turn
      final nextDecision = _decisionForNode[opponentChild.id];
      if (nextDecision != null) {
        final decState = _reviewStates[nextDecision.id];
        final isDue = decState == null || decState.isDueAt(now);
        if (isDue) {
          // Found next due decision along this branch!
          _dueQueue.removeWhere((d) => d.id == nextDecision.id);
          _currentPrompt = _buildPrompt(decision: nextDecision, node: opponentChild);
          return ReviewStepResult(
            isCorrect: true,
            movePlayed: expectedMatch,
            expectedMoves: prompt.expectedMoves,
            updatedState: updatedState,
            event: event,
            autoPlayedMoves: autoPlayed,
            nextPrompt: _currentPrompt,
            sessionComplete: false,
          );
        }
      }

      // User position was not due: auto-play learned user continuation
      if (opponentChild.children.isNotEmpty) {
        final userChild = opponentChild.children.first;
        final userMove = userChild.incomingMove!;
        autoPlayed.add(
          AutoPlayedMove(
            move: userMove,
            fenBefore: opponentChild.fen,
            fenAfter: userChild.fen,
            isUserMove: true,
            comment: userChild.comment,
          ),
        );
        activeNode = userChild;
      } else {
        activeNode = null;
      }
    }

    // Reached the end of the current line; advance to the next due decision in queue
    _advanceToNextDue();

    return ReviewStepResult(
      isCorrect: true,
      movePlayed: expectedMatch,
      expectedMoves: prompt.expectedMoves,
      updatedState: updatedState,
      event: event,
      autoPlayedMoves: autoPlayed,
      nextPrompt: _currentPrompt,
      sessionComplete: isComplete,
    );
  }

  /// Advance to the next due item after acknowledging an incorrect answer.
  void continueAfterIncorrect() {
    _advanceToNextDue();
  }

  /// Skip the current prompt, moving it to the back of the queue.
  ReviewPrompt? skip() {
    if (_currentPrompt == null) return null;
    final skippedDecision = _currentPrompt!.decision;
    _dueQueue.add(skippedDecision);
    _advanceToNextDue();
    return _currentPrompt;
  }

  // ---------------------------------------------------------------------------
  // Internal Helpers
  // ---------------------------------------------------------------------------

  void _advanceToNextDue() {
    if (_dueQueue.isEmpty) {
      _currentPrompt = null;
      return;
    }
    final nextDecision = _dueQueue.removeAt(0);
    final node = _nodesById[nextDecision.nodeId];
    _currentPrompt = _buildPrompt(decision: nextDecision, node: node);
  }

  ReviewPrompt _buildPrompt({required RepertoireDecision decision, RepertoireNode? node}) {
    final chapter = _chapters[decision.chapterId];
    final study = _studies[decision.studyId];

    final fen =
        node?.fen ??
        chapter?.startingFen ??
        'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
    final fenKey = node?.fenKey ?? fen;
    final side = _sideFromFen(fen);

    return ReviewPrompt(
      decision: decision,
      studyId: decision.studyId,
      chapterId: decision.chapterId,
      nodeId: decision.nodeId,
      fen: fen,
      fenKey: fenKey,
      sideToMove: side,
      expectedMoves: decision.expectedMoves,
      currentNode: node,
      comment: node?.comment,
      chapterTitle: chapter?.title,
      studyTitle: study?.title,
    );
  }

  RepertoireNode? _findChildForMove(RepertoireNode? node, RepertoireMove move) {
    if (node == null) return null;
    return node.children.where((c) {
      final inc = c.incomingMove;
      if (inc == null) return false;
      final matchSquares =
          inc.from.toLowerCase() == move.from.toLowerCase() &&
          inc.to.toLowerCase() == move.to.toLowerCase();
      if (!matchSquares) return false;
      if (move.promotion != null && inc.promotion != null) {
        return inc.promotion!.toLowerCase() == move.promotion!.toLowerCase();
      }
      return true;
    }).firstOrNull;
  }

  void _indexNodes(RepertoireNode node) {
    _nodesById[node.id] = node;
    for (final child in node.children) {
      _indexNodes(child);
    }
  }

  Side _sideFromFen(String fen) {
    final parts = fen.trim().split(RegExp(r'\s+'));
    if (parts.length > 1 && parts[1].toLowerCase() == 'b') {
      return Side.black;
    }
    return Side.white;
  }
}
