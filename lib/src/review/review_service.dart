// Copyright (C) 2024 ChessSRS contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:chess_srs/src/domain/domain.dart';
import 'package:chess_srs/src/persistence/persistence.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider for the application's [Clock].
final clockProvider = Provider<Clock>((ref) => const SystemClock());

/// Provider for the application's [Scheduler].
final schedulerProvider = Provider<Scheduler>((ref) => const SimpleScheduler());

/// Provider for [ReviewService].
final reviewServiceProvider = Provider<ReviewService>((ref) {
  final repoAsync = ref.watch(srsStudyRepositoryProvider);
  final repo = repoAsync.asData?.value;
  final scheduler = ref.watch(schedulerProvider);
  final clock = ref.watch(clockProvider);

  if (repo == null) {
    throw StateError('StudyRepository is not yet initialized');
  }

  return ReviewService(repository: repo, scheduler: scheduler, clock: clock);
});

/// Application service orchestrating review sessions, local persistence,
/// and SRS updates.
class DueCountsSummary {
  const DueCountsSummary({
    required this.totalDueCount,
    required this.studyDueCounts,
    required this.openingDueCounts,
  });

  final int totalDueCount;
  final Map<String, int> studyDueCounts;
  final Map<String, int> openingDueCounts;
}

class ReviewService {
  ReviewService({
    required this.repository,
    this.scheduler = const SimpleScheduler(),
    this.clock = const SystemClock(),
  });

  final StudyRepository repository;
  final Scheduler scheduler;
  final Clock clock;

  ReviewSession? _activeSession;
  ReviewSession? get activeSession => _activeSession;

  /// Starts a new review session for the given [scope].
  Future<ReviewSession> startSession({
    ReviewScope scope = const ReviewScope.all(),
    ReviewMode mode = ReviewMode.srs,
  }) async {
    final studies = await repository.getAllStudies();
    final allChapters = <Chapter>[];
    for (final study in studies) {
      final chapters = await repository.getChaptersByStudy(study.id);
      allChapters.addAll(chapters);
    }

    final decisions = scope.chapterId != null
        ? await repository.getDecisionsByChapter(scope.chapterId!)
        : (scope.studyId != null
              ? await repository.getDecisionsByStudy(scope.studyId!)
              : (scope.openingFamily != null
                    ? await _getOpeningDecisions(allChapters, scope.openingFamily!, studies)
                    : await _getActiveDecisions(studies)));

    final reviewStatesList = await repository.getAllReviewStates();
    final reviewStates = {for (final s in reviewStatesList) s.decisionId: s};

    final engine = ReviewEngine(scheduler: scheduler, clock: clock);

    final session = engine.createSession(
      studies: studies,
      chapters: allChapters,
      decisions: decisions,
      reviewStates: reviewStates,
      scope: scope,
      mode: mode,
    );

    _activeSession = session;
    return session;
  }

  /// Submits a user move for the current prompt in the active session.
  ///
  /// Incrementally persists the resulting [ReviewState] and [ReviewEvent]
  /// to SQLite without modifying the study or chapter trees (QUALITY.md §1.5).
  Future<ReviewStepResult> submitMove({
    required String from,
    required String to,
    String? promotion,
  }) async {
    final session = _activeSession;
    if (session == null) {
      throw StateError('No active review session');
    }

    final result = session.submitMove(from: from, to: to, promotion: promotion);

    // Incremental persistence (Invariant §1.5)
    await repository.saveReviewState(result.updatedState);
    if (result.event != null) {
      await repository.saveReviewEvent(result.event!);
    }

    return result;
  }

  /// Retries a move attempt on the current prompt after an incorrect answer.
  ReviewStepResult retryMove({required String from, required String to, String? promotion}) {
    final session = _activeSession;
    if (session == null) {
      throw StateError('No active review session');
    }

    return session.retryMove(from: from, to: to, promotion: promotion);
  }

  /// Advances after an incorrect answer has been acknowledged by the user.
  void continueAfterIncorrect() {
    _activeSession?.continueAfterIncorrect();
  }

  /// Skips the active prompt to the end of the session.
  ReviewPrompt? skipCurrentPrompt() {
    return _activeSession?.skip();
  }

  /// Returns the number of due decisions for the given [scope] at current clock time.
  Future<int> getDueCount({ReviewScope scope = const ReviewScope.all()}) async {
    final studies = await repository.getAllStudies();
    final summary = await getDueSummary(studies: studies, scope: scope);
    return summary.totalDueCount;
  }

  /// Returns a batched summary of due counts for all studies, opening hubs, and the given [scope].
  ///
  /// Computes all counts in a single in-memory pass over decisions without reloading
  /// recursive chapter trees or performing N+1 database queries.
  Future<DueCountsSummary> getDueSummary({
    required List<Study> studies,
    ReviewScope scope = const ReviewScope.all(),
  }) async {
    final activeStudyIds = studies.where((s) => s.isActive).map((s) => s.id).toSet();
    final chapterOpenings = await repository.getChapterOpenings();
    final allDecisions = await repository.getAllDecisions();
    final reviewStatesList = await repository.getAllReviewStates();
    final reviewStates = {for (final s in reviewStatesList) s.decisionId: s};
    final now = clock.now();

    final studyDueCounts = <String, int>{for (final s in studies) s.id: 0};
    final openingFamilies = <String>{};
    for (final op in chapterOpenings.values) {
      if (op != null && op.trim().isNotEmpty) {
        openingFamilies.add(op.trim());
      }
    }
    final openingDueCounts = <String, int>{for (final op in openingFamilies) op: 0};

    var totalDueCount = 0;

    for (final d in allDecisions) {
      final state = reviewStates[d.id];
      final isDue = state == null || state.isDueAt(now);
      if (!isDue) continue;

      if (studyDueCounts.containsKey(d.studyId)) {
        studyDueCounts[d.studyId] = (studyDueCounts[d.studyId] ?? 0) + 1;
      }

      final opening = chapterOpenings[d.chapterId]?.trim();
      final isActiveStudy = activeStudyIds.contains(d.studyId);

      if (isActiveStudy && opening != null && opening.isNotEmpty) {
        if (openingDueCounts.containsKey(opening)) {
          openingDueCounts[opening] = (openingDueCounts[opening] ?? 0) + 1;
        }
      }

      if (scope.matches(studyId: d.studyId, chapterId: d.chapterId, openingFamily: opening)) {
        if (scope.studyId != null) {
          totalDueCount++;
        } else if (scope.openingFamily != null) {
          if (isActiveStudy) totalDueCount++;
        } else {
          if (isActiveStudy) totalDueCount++;
        }
      }
    }

    return DueCountsSummary(
      totalDueCount: totalDueCount,
      studyDueCounts: studyDueCounts,
      openingDueCounts: openingDueCounts,
    );
  }

  Future<List<RepertoireDecision>> _getActiveDecisions(List<Study> studies) async {
    final activeStudyIds = studies.where((s) => s.isActive).map((s) => s.id).toSet();
    final allDecisions = await repository.getAllDecisions();
    return allDecisions.where((d) => activeStudyIds.contains(d.studyId)).toList();
  }

  Future<List<RepertoireDecision>> _getOpeningDecisions(
    List<Chapter> allChapters,
    String openingFamily,
    List<Study> studies,
  ) async {
    final activeStudyIds = studies.where((s) => s.isActive).map((s) => s.id).toSet();
    final matchingChapterIds = allChapters
        .where((c) => c.opening == openingFamily && activeStudyIds.contains(c.studyId))
        .map((c) => c.id)
        .toSet();
    final allDecisions = await repository.getAllDecisions();
    return allDecisions.where((d) => matchingChapterIds.contains(d.chapterId)).toList();
  }
}
