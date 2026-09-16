// Copyright (C) 2024 ChessSRS contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:chess_srs/src/domain/domain.dart';
import 'package:chess_srs/src/import/pgn_exporter.dart';
import 'package:chess_srs/src/import/pgn_importer.dart';
import 'package:chess_srs/src/persistence/persistence.dart';
import 'package:chess_srs/src/review/review_service.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ReviewFeedback { none, correct, incorrect }

class ReviewScreenState {
  const ReviewScreenState({
    required this.studies,
    required this.scope,
    required this.totalDueCount,
    required this.studyDueCounts,
    this.session,
    this.currentPrompt,
    this.boardPosition,
    this.boardOrientation = Side.white,
    this.lastMove,
    this.feedback = ReviewFeedback.none,
    this.expectedMove,
    this.isLapseAcknowledged = true,
    this.revealedComment,
    this.mode = ReviewMode.srs,
  });

  final List<Study> studies;
  final ReviewScope scope;
  final int totalDueCount;
  final Map<String, int> studyDueCounts;
  final ReviewSession? session;
  final ReviewPrompt? currentPrompt;
  final Position? boardPosition;
  final Side boardOrientation;
  final Move? lastMove;
  final ReviewFeedback feedback;
  final RepertoireMove? expectedMove;
  final bool isLapseAcknowledged;
  final String? revealedComment;
  final ReviewMode mode;

  bool get hasStudies => studies.isNotEmpty;
  bool get hasDuePositions => (totalDueCount > 0 || isPracticeMode) && currentPrompt != null;
  bool get isComplete =>
      hasStudies && ((totalDueCount == 0 && !isPracticeMode) || currentPrompt == null);
  bool get isPracticeMode => mode == ReviewMode.practice;

  ReviewScreenState copyWith({
    List<Study>? studies,
    ReviewScope? scope,
    int? totalDueCount,
    Map<String, int>? studyDueCounts,
    ReviewSession? session,
    ReviewPrompt? currentPrompt,
    bool clearPrompt = false,
    Position? boardPosition,
    Side? boardOrientation,
    Move? lastMove,
    bool clearLastMove = false,
    ReviewFeedback? feedback,
    RepertoireMove? expectedMove,
    bool clearExpectedMove = false,
    bool? isLapseAcknowledged,
    String? revealedComment,
    bool clearRevealedComment = false,
    ReviewMode? mode,
  }) {
    return ReviewScreenState(
      studies: studies ?? this.studies,
      scope: scope ?? this.scope,
      totalDueCount: totalDueCount ?? this.totalDueCount,
      studyDueCounts: studyDueCounts ?? this.studyDueCounts,
      session: session ?? this.session,
      currentPrompt: clearPrompt ? null : (currentPrompt ?? this.currentPrompt),
      boardPosition: boardPosition ?? this.boardPosition,
      boardOrientation: boardOrientation ?? this.boardOrientation,
      lastMove: clearLastMove ? null : (lastMove ?? this.lastMove),
      feedback: feedback ?? this.feedback,
      expectedMove: clearExpectedMove ? null : (expectedMove ?? this.expectedMove),
      isLapseAcknowledged: isLapseAcknowledged ?? this.isLapseAcknowledged,
      revealedComment: clearRevealedComment ? null : (revealedComment ?? this.revealedComment),
      mode: mode ?? this.mode,
    );
  }
}

/// Provider for [ReviewController].
final reviewControllerProvider = AsyncNotifierProvider<ReviewController, ReviewScreenState>(
  ReviewController.new,
);

class ReviewController extends AsyncNotifier<ReviewScreenState> {
  ReviewService get _service => ref.read(reviewServiceProvider);
  StudyRepository get _repository => ref.read(reviewServiceProvider).repository;

  @override
  Future<ReviewScreenState> build() async {
    // Wait for repository provider to be ready if needed
    final repoAsync = ref.watch(srsStudyRepositoryProvider);
    final repo = repoAsync.asData?.value;
    if (repo == null) {
      return const ReviewScreenState(
        studies: [],
        scope: ReviewScope.all(),
        totalDueCount: 0,
        studyDueCounts: {},
      );
    }

    return await _loadState(const ReviewScope.all());
  }

  Future<ReviewScreenState> _loadState(
    ReviewScope scope, [
    ReviewMode mode = ReviewMode.srs,
  ]) async {
    final studies = await _repository.getAllStudies();
    final studyDueCounts = <String, int>{};
    for (final study in studies) {
      final count = await _service.getDueCount(scope: ReviewScope.study(study.id));
      studyDueCounts[study.id] = count;
    }
    final totalDueCount = await _service.getDueCount(scope: scope);

    if (studies.isEmpty) {
      return ReviewScreenState(
        studies: studies,
        scope: scope,
        mode: mode,
        totalDueCount: 0,
        studyDueCounts: studyDueCounts,
      );
    }

    final session = await _service.startSession(scope: scope, mode: mode);
    final prompt = session.currentPrompt;

    Position? position;
    Side orientation = Side.white;
    Move? lastMove;

    if (prompt != null) {
      position = _parseFen(prompt.fen);
      orientation = prompt.sideToMove;
    }

    return ReviewScreenState(
      studies: studies,
      scope: scope,
      mode: mode,
      totalDueCount: totalDueCount,
      studyDueCounts: studyDueCounts,
      session: session,
      currentPrompt: prompt,
      boardPosition: position,
      boardOrientation: orientation,
      lastMove: lastMove,
      feedback: ReviewFeedback.none,
      isLapseAcknowledged: true,
    );
  }

  /// Changes the active review scope (all studies or a specific study).
  Future<void> changeScope(ReviewScope scope) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _loadState(scope));
  }

  /// Reloads the session and due counts for the current scope.
  Future<void> reload() async {
    final currentState = state.asData?.value;
    final currentScope = currentState?.scope ?? const ReviewScope.all();
    final currentMode = currentState?.mode ?? ReviewMode.srs;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _loadState(currentScope, currentMode));
  }

  /// Starts non-destructive pre-match rehearsal / cram mode (PRODUCT.md Journey 4).
  Future<void> startPracticeMode({ReviewScope? scope}) async {
    final targetScope = scope ?? state.asData?.value.scope ?? const ReviewScope.all();
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _loadState(targetScope, ReviewMode.practice));
  }

  /// Exits practice mode and returns to standard SRS review.
  Future<void> exitPracticeMode() async {
    final currentScope = state.asData?.value.scope ?? const ReviewScope.all();
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _loadState(currentScope, ReviewMode.srs));
  }

  /// Toggles whether a study is included in the daily review pool (PRODUCT.md Journey 5).
  Future<void> toggleStudyActive(String studyId, bool isActive) async {
    await _repository.updateStudyActive(studyId, isActive);
    await reload();
  }

  /// Exports all chapters of [studyId] to standard PGN string for explore/analysis mode.
  Future<String?> exportStudyPgn(String studyId) async {
    final study = await _repository.getStudy(studyId);
    if (study == null) return null;
    final chapters = await _repository.getChaptersByStudy(studyId);
    return studyToPgn(study, chapters);
  }

  /// Handles move animation, opponent reply pacing, and transition to the next prompt.
  Future<void> _handleCorrectAdvancement({
    required ReviewScreenState currentState,
    required ReviewStepResult result,
    required Move userMove,
    required bool isFirstAttempt,
  }) async {
    final currentPos = currentState.boardPosition;
    final posAfterUser = currentPos != null && userMove is NormalMove
        ? currentPos.play(userMove)
        : null;

    // 1. Immediately show user's move on the board
    state = AsyncData(
      currentState.copyWith(
        boardPosition: posAfterUser ?? currentState.boardPosition,
        lastMove: userMove,
        feedback: ReviewFeedback.none,
        clearExpectedMove: true,
        isLapseAcknowledged: true,
        revealedComment: _resolveComment(
          currentState.currentPrompt,
          result.expectedMoves.firstOrNull,
        ),
      ),
    );

    // 2. If opponent has an auto-reply, pause briefly then show it
    final opponentMoves = result.autoPlayedMoves.where((m) => !m.isUserMove).toList();
    if (opponentMoves.isNotEmpty) {
      await Future<void>.delayed(const Duration(milliseconds: 350));
      if (!ref.mounted) return;
      final oppMove = opponentMoves.first;
      final oppNormalMove = NormalMove(
        from: Square.fromName(oppMove.move.from),
        to: Square.fromName(oppMove.move.to),
        promotion: oppMove.move.promotion != null ? Role.fromChar(oppMove.move.promotion!) : null,
      );
      final oppPos = _parseFen(oppMove.fenAfter);

      state = AsyncData(state.value!.copyWith(boardPosition: oppPos, lastMove: oppNormalMove));
      await Future<void>.delayed(const Duration(milliseconds: 200));
      if (!ref.mounted) return;
    }

    // 3. Advance to next prompt
    final session = _service.activeSession!;
    final nextPrompt = session.currentPrompt;

    Position? nextPosition;
    Side nextOrientation = currentState.boardOrientation;
    if (nextPrompt != null) {
      nextPosition = _parseFen(nextPrompt.fen);
      nextOrientation = nextPrompt.sideToMove;
    }

    final newTotalDue = isFirstAttempt && currentState.totalDueCount > 0
        ? currentState.totalDueCount - 1
        : currentState.totalDueCount;

    final studyCounts = Map<String, int>.from(currentState.studyDueCounts);
    final currentStudyId = currentState.currentPrompt!.studyId;
    if (isFirstAttempt &&
        studyCounts.containsKey(currentStudyId) &&
        studyCounts[currentStudyId]! > 0) {
      studyCounts[currentStudyId] = studyCounts[currentStudyId]! - 1;
    }

    state = AsyncData(
      state.value!.copyWith(
        totalDueCount: newTotalDue,
        studyDueCounts: studyCounts,
        session: session,
        currentPrompt: nextPrompt,
        clearPrompt: nextPrompt == null,
        boardPosition: nextPosition,
        boardOrientation: nextOrientation,
        feedback: ReviewFeedback.none,
        clearExpectedMove: true,
        isLapseAcknowledged: true,
        clearRevealedComment: true,
      ),
    );
  }

  /// Submits a move played by the user.
  Future<ReviewStepResult?> onUserMove(Move move) async {
    final currentState = state.asData?.value;
    if (currentState == null || currentState.currentPrompt == null) return null;
    if (move is! NormalMove) return null;

    final from = move.from.name;
    final to = move.to.name;
    final promotion = move.promotion?.letter;

    final isRetrying = currentState.feedback == ReviewFeedback.incorrect;

    if (isRetrying) {
      // Reguess attempt after previous lapse
      final result = _service.retryMove(from: from, to: to, promotion: promotion);
      if (result.isCorrect) {
        await _handleCorrectAdvancement(
          currentState: currentState,
          result: result,
          userMove: move,
          isFirstAttempt: false,
        );
      } else {
        state = AsyncData(
          currentState.copyWith(
            feedback: ReviewFeedback.incorrect,
            expectedMove: result.expectedMoves.firstOrNull,
            isLapseAcknowledged: false,
            revealedComment: _resolveComment(
              currentState.currentPrompt,
              result.expectedMoves.firstOrNull,
            ),
          ),
        );
      }
      return result;
    }

    // Initial move attempt on this prompt
    final result = await _service.submitMove(from: from, to: to, promotion: promotion);

    if (result.isCorrect) {
      await _handleCorrectAdvancement(
        currentState: currentState,
        result: result,
        userMove: move,
        isFirstAttempt: true,
      );
    } else {
      // Lapse: show expected move banner, allow user to reguess on board
      state = AsyncData(
        currentState.copyWith(
          feedback: ReviewFeedback.incorrect,
          expectedMove: result.expectedMoves.firstOrNull,
          isLapseAcknowledged: false,
          revealedComment: _resolveComment(
            currentState.currentPrompt,
            result.expectedMoves.firstOrNull,
          ),
        ),
      );
    }

    return result;
  }

  /// Acknowledges a lapse, clearing the expected move arrow and advancing.
  void acknowledgeLapse() {
    final currentState = state.asData?.value;
    if (currentState == null) return;

    _service.continueAfterIncorrect();
    final session = _service.activeSession;
    final nextPrompt = session?.currentPrompt;

    Position? nextPosition;
    Side nextOrientation = currentState.boardOrientation;
    if (nextPrompt != null) {
      nextPosition = _parseFen(nextPrompt.fen);
      nextOrientation = nextPrompt.sideToMove;
    }

    state = AsyncData(
      currentState.copyWith(
        currentPrompt: nextPrompt,
        clearPrompt: nextPrompt == null,
        boardPosition: nextPosition,
        boardOrientation: nextOrientation,
        feedback: ReviewFeedback.none,
        clearExpectedMove: true,
        isLapseAcknowledged: true,
        clearLastMove: true,
        clearRevealedComment: true,
      ),
    );
  }

  /// Skips the current prompt, moving it to the back of the queue.
  void skip() {
    final currentState = state.asData?.value;
    if (currentState == null || currentState.currentPrompt == null) return;

    final nextPrompt = _service.skipCurrentPrompt();

    Position? nextPosition;
    Side nextOrientation = currentState.boardOrientation;
    if (nextPrompt != null) {
      nextPosition = _parseFen(nextPrompt.fen);
      nextOrientation = nextPrompt.sideToMove;
    }

    state = AsyncData(
      currentState.copyWith(
        currentPrompt: nextPrompt,
        clearPrompt: nextPrompt == null,
        boardPosition: nextPosition,
        boardOrientation: nextOrientation,
        feedback: ReviewFeedback.none,
        clearExpectedMove: true,
        isLapseAcknowledged: true,
        clearLastMove: true,
        clearRevealedComment: true,
      ),
    );
  }

  /// Imports a repertoire from PGN text and immediately loads it for review.
  Future<ImportResult> importPgnText({
    required String pgnText,
    String? title,
    Side? repertoireSide,
  }) async {
    final result = importPgn(
      pgnText,
      studyTitle: title ?? 'Imported Study',
      repertoireSide: repertoireSide,
    );

    await _repository.saveImportResult(result);
    await changeScope(ReviewScope.study(result.study.id));
    return result;
  }

  String? _resolveComment(ReviewPrompt? prompt, RepertoireMove? expectedMove) {
    if (prompt == null) return null;
    if (expectedMove != null && prompt.currentNode != null) {
      final child = prompt.currentNode!.childForMove(expectedMove);
      if (child?.comment != null && child!.comment!.trim().isNotEmpty) {
        return child.comment!.trim();
      }
    }
    return prompt.comment?.trim();
  }

  Position _parseFen(String fen) {
    try {
      final setup = Setup.parseFen(fen);
      return Chess.fromSetup(setup);
    } catch (_) {
      return Chess.initial;
    }
  }
}
