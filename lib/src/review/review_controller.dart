// Copyright (C) 2024 ChessSRS contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:chess_srs/src/domain/domain.dart';
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

  bool get hasStudies => studies.isNotEmpty;
  bool get hasDuePositions => totalDueCount > 0 && currentPrompt != null;
  bool get isComplete => hasStudies && (totalDueCount == 0 || currentPrompt == null);

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

  Future<ReviewScreenState> _loadState(ReviewScope scope) async {
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
        totalDueCount: 0,
        studyDueCounts: studyDueCounts,
      );
    }

    final session = await _service.startSession(scope: scope);
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
    final currentScope = state.asData?.value.scope ?? const ReviewScope.all();
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _loadState(currentScope));
  }

  /// Submits a move played by the user.
  Future<ReviewStepResult?> onUserMove(Move move) async {
    final currentState = state.asData?.value;
    if (currentState == null || currentState.currentPrompt == null) return null;
    if (move is! NormalMove) return null;

    final from = move.from.name;
    final to = move.to.name;
    final promotion = move.promotion?.letter;

    final result = await _service.submitMove(from: from, to: to, promotion: promotion);

    if (result.isCorrect) {
      final session = _service.activeSession!;
      final nextPrompt = session.currentPrompt;

      Position? nextPosition;
      Side nextOrientation = currentState.boardOrientation;
      if (nextPrompt != null) {
        nextPosition = _parseFen(nextPrompt.fen);
        nextOrientation = nextPrompt.sideToMove;
      }

      final newTotalDue = (currentState.totalDueCount > 0) ? currentState.totalDueCount - 1 : 0;

      final studyCounts = Map<String, int>.from(currentState.studyDueCounts);
      final currentStudyId = currentState.currentPrompt!.studyId;
      if (studyCounts.containsKey(currentStudyId) && studyCounts[currentStudyId]! > 0) {
        studyCounts[currentStudyId] = studyCounts[currentStudyId]! - 1;
      }

      state = AsyncData(
        currentState.copyWith(
          totalDueCount: newTotalDue,
          studyDueCounts: studyCounts,
          session: session,
          currentPrompt: nextPrompt,
          clearPrompt: nextPrompt == null,
          boardPosition: nextPosition,
          boardOrientation: nextOrientation,
          lastMove: move,
          feedback: ReviewFeedback.correct,
          clearExpectedMove: true,
          isLapseAcknowledged: true,
        ),
      );
    } else {
      // Lapse: show expected move and wait for user acknowledgment
      state = AsyncData(
        currentState.copyWith(
          feedback: ReviewFeedback.incorrect,
          expectedMove: result.expectedMoves.firstOrNull,
          isLapseAcknowledged: false,
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
    await reload();
    return result;
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
