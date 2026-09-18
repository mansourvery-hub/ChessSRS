// Copyright (C) 2024 ChessSRS contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:math';

import 'package:chess_srs/src/domain/chapter.dart';
import 'package:chess_srs/src/domain/clock.dart';
import 'package:chess_srs/src/domain/repertoire_decision.dart';
import 'package:chess_srs/src/domain/repertoire_move.dart';
import 'package:chess_srs/src/domain/repertoire_node.dart';
import 'package:chess_srs/src/domain/review/review_mode.dart';
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
/// queue prefetching and buffering (chessrs PracticeMainPanel.tsx semantics),
/// and deterministic time testing via [Clock] (Invariant §3.2).
class ReviewSession {
  ReviewSession({
    required List<Study> studies,
    required List<Chapter> chapters,
    required List<RepertoireDecision> decisions,
    required Map<String, ReviewState> reviewStates,
    this.scope = const ReviewScope.all(),
    this.mode = ReviewMode.srs,
    this.scheduler = const SimpleScheduler(),
    this.clock = const SystemClock(),
    this.prefetchBatchSize = 25,
    this.prefetchRefillThreshold = 3,
    Random? random,
  }) : _random = random ?? Random(),
       _studies = {for (final s in studies) s.id: s},
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
    final queuedCanonicalIds = <String>{};
    for (final d in decisions) {
      final chapter = _chapters[d.chapterId];
      if (!scope.matches(
        studyId: d.studyId,
        chapterId: d.chapterId,
        openingFamily: chapter?.opening,
      )) {
        continue;
      }
      final state = _reviewStates[d.canonicalId] ?? _reviewStates[d.id];
      if (mode == ReviewMode.practice || state == null || state.isDueAt(now)) {
        // In multi-study scope, deduplicate shared canonical transpositions
        if (scope.studyId == null && scope.chapterId == null) {
          if (!queuedCanonicalIds.add(d.canonicalId)) {
            continue;
          }
        }
        _unbufferedQueue.add(d);
      }
    }

    _initialDueCount = _unbufferedQueue.length;
    _refillPrefetchBuffer();
    _advanceToNextDue();
  }

  final ReviewScope scope;
  final ReviewMode mode;
  final Scheduler scheduler;
  final Clock clock;
  final Random _random;

  /// Maximum batch size of due decisions to buffer in the active queue at once.
  /// Null disables batching and buffers the entire queue.
  final int? prefetchBatchSize;

  /// Threshold at which the active prefetch buffer refills from unbuffered decisions.
  final int prefetchRefillThreshold;

  final Map<String, Study> _studies;
  final Map<String, Chapter> _chapters;
  final Map<String, ReviewState> _reviewStates;
  final Map<String, RepertoireDecision> _decisionForNode;
  final Map<String, RepertoireNode> _nodesById = {};
  final Map<String, RepertoireNode> _parentOfNode = {};

  final List<RepertoireDecision> _dueQueue = [];
  final List<RepertoireDecision> _unbufferedQueue = [];
  ReviewPrompt? _currentPrompt;
  int _completedCount = 0;
  late final int _initialDueCount;

  void _refillPrefetchBuffer() {
    if (prefetchBatchSize == null) {
      _dueQueue.addAll(_unbufferedQueue);
      _unbufferedQueue.clear();
      return;
    }
    while (_dueQueue.length < prefetchBatchSize! && _unbufferedQueue.isNotEmpty) {
      _dueQueue.add(_unbufferedQueue.removeAt(0));
    }
  }

  // ---------------------------------------------------------------------------
  // Getters
  // ---------------------------------------------------------------------------

  ReviewPrompt? get currentPrompt => _currentPrompt;
  int get remainingDueCount =>
      _dueQueue.length + _unbufferedQueue.length + (_currentPrompt != null ? 1 : 0);
  int get completedCount => _completedCount;
  int get initialDueCount => _initialDueCount;
  bool get isComplete => _currentPrompt == null && _dueQueue.isEmpty && _unbufferedQueue.isEmpty;
  Map<String, ReviewState> get reviewStates => Map.unmodifiable(_reviewStates);

  /// Returns the chapter with [chapterId] if present in this session.
  Chapter? getChapter(String chapterId) => _chapters[chapterId];

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
    final prevState =
        _reviewStates[decision.canonicalId] ??
        _reviewStates[decision.id] ??
        ReviewState.initial(decisionId: decision.canonicalId);

    // Validate move against expected repertoire moves (Invariant §2.1)
    final movePlayed = RepertoireMove(from: from, to: to, promotion: promotion);
    final expectedMatch = prompt.expectedMoves.where((exp) => exp.matches(movePlayed)).firstOrNull;

    final now = clock.now();

    if (expectedMatch != null) {
      // -----------------------------------------------------------------------
      // CORRECT MOVE
      // -----------------------------------------------------------------------
      ReviewState nextState;
      ReviewEvent? event;

      if (mode == ReviewMode.practice) {
        nextState = prevState;
        event = null;
      } else {
        nextState = scheduler.schedule(previous: prevState, result: ReviewResult.correct, now: now);
        _reviewStates[decision.canonicalId] = nextState;
        _reviewStates[decision.id] = nextState;

        event = ReviewEvent(
          decisionId: decision.canonicalId,
          when: now,
          result: ReviewResult.correct,
          oldState: prevState,
          newState: nextState,
        );
      }

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

      ReviewState nextState;
      ReviewEvent? event;

      if (mode == ReviewMode.practice) {
        nextState = prevState;
        event = null;
      } else {
        nextState = scheduler.schedule(
          previous: prevState,
          result: ReviewResult.incorrect,
          now: now,
        );
        _reviewStates[decision.canonicalId] = nextState;
        _reviewStates[decision.id] = nextState;

        event = ReviewEvent(
          decisionId: decision.canonicalId,
          when: now,
          result: ReviewResult.incorrect,
          oldState: prevState,
          newState: nextState,
        );
      }

      // Re-queue the failed decision at the end of the session queue
      // so the user can re-test it before completing the session
      _dueQueue.removeWhere((d) => d.id == decision.id);
      _unbufferedQueue.removeWhere((d) => d.id == decision.id);
      if (_unbufferedQueue.isNotEmpty) {
        _unbufferedQueue.add(decision);
      } else {
        _dueQueue.add(decision);
      }

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

    final movePlayed = RepertoireMove(from: from, to: to, promotion: promotion);
    final expectedMatch = prompt.expectedMoves.where((exp) => exp.matches(movePlayed)).firstOrNull;

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

      // Opponent turn: select response using due-aware & weighted selection (Listudy semantics)
      final opponentChild = _selectOpponentChild(activeNode, now);
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
        final decState = _reviewStates[nextDecision.canonicalId] ?? _reviewStates[nextDecision.id];
        final isDue = mode == ReviewMode.practice || decState == null || decState.isDueAt(now);
        if (isDue) {
          // Found next due decision along this branch!
          _dueQueue.removeWhere(
            (d) => d.id == nextDecision.id || d.canonicalId == nextDecision.canonicalId,
          );
          _unbufferedQueue.removeWhere(
            (d) => d.id == nextDecision.id || d.canonicalId == nextDecision.canonicalId,
          );
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
    if (_unbufferedQueue.isNotEmpty) {
      _unbufferedQueue.add(skippedDecision);
    } else {
      _dueQueue.add(skippedDecision);
    }
    _advanceToNextDue();
    return _currentPrompt;
  }

  // ---------------------------------------------------------------------------
  // Internal Helpers
  // ---------------------------------------------------------------------------

  void _advanceToNextDue() {
    if (_dueQueue.length <= prefetchRefillThreshold) {
      _refillPrefetchBuffer();
    }
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
    final parentNode = node != null ? _parentOfNode[node.id] : null;

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
      parentFen: parentNode?.fen,
      incomingMove: node?.incomingMove,
    );
  }

  RepertoireNode? _findChildForMove(RepertoireNode? node, RepertoireMove move) {
    if (node == null) return null;
    return node.childForMove(move);
  }

  void _indexNodes(RepertoireNode node, [RepertoireNode? parent]) {
    _nodesById[node.id] = node;
    if (parent != null) {
      _parentOfNode[node.id] = parent;
    }
    for (final child in node.children) {
      _indexNodes(child, node);
    }
  }

  Side _sideFromFen(String fen) {
    final parts = fen.trim().split(RegExp(r'\s+'));
    if (parts.length > 1 && parts[1].toLowerCase() == 'b') {
      return Side.black;
    }
    return Side.white;
  }

  /// Selects the opponent response among multiple children.
  ///
  /// Uses Listudy-inspired due-aware selection (docs/review.md §Opponent Variation Selection):
  /// 1. Prioritizes opponent branches that lead to moves currently due for review.
  /// 2. If multiple branches have due moves, selects among them using weighted
  ///    randomness proportional to due move density.
  /// 3. In practice mode or if no branch has due moves, selects among all branches
  ///    using anti-repetition weighted randomness proportional to subtree size.
  RepertoireNode _selectOpponentChild(RepertoireNode node, DateTime now) {
    if (node.children.length == 1) {
      return node.children.first;
    }

    final dueCounts = <RepertoireNode, int>{};
    for (final child in node.children) {
      dueCounts[child] = _countDueDecisionsInSubtree(child, now);
    }

    final dueChildren = node.children.where((c) => (dueCounts[c] ?? 0) > 0).toList();
    if (dueChildren.isNotEmpty) {
      return _selectWeighted(dueChildren, dueCounts);
    }

    // Fallback: weight by total subtree size so larger variations get proportionate practice
    final subtreeSizes = <RepertoireNode, int>{};
    for (final child in node.children) {
      subtreeSizes[child] = _countNodesInSubtree(child);
    }
    return _selectWeighted(node.children, subtreeSizes);
  }

  int _countDueDecisionsInSubtree(RepertoireNode node, DateTime now) {
    var count = 0;
    final decision = _decisionForNode[node.id];
    if (decision != null) {
      final state = _reviewStates[decision.id];
      final isDue = mode == ReviewMode.practice || state == null || state.isDueAt(now);
      if (isDue) {
        count++;
      }
    }
    for (final child in node.children) {
      count += _countDueDecisionsInSubtree(child, now);
    }
    return count;
  }

  int _countNodesInSubtree(RepertoireNode node) {
    var count = 1;
    for (final child in node.children) {
      count += _countNodesInSubtree(child);
    }
    return count;
  }

  RepertoireNode _selectWeighted(
    List<RepertoireNode> candidates,
    Map<RepertoireNode, int> weights,
  ) {
    if (candidates.length == 1) return candidates.first;

    final totalWeight = candidates.fold<int>(0, (sum, c) => sum + (weights[c] ?? 1));
    if (totalWeight <= 0) {
      return candidates[_random.nextInt(candidates.length)];
    }

    var roll = _random.nextInt(totalWeight);
    for (final candidate in candidates) {
      final weight = weights[candidate] ?? 1;
      if (roll < weight) {
        return candidate;
      }
      roll -= weight;
    }
    return candidates.first;
  }
}
