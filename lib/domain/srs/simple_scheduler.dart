import 'review_result.dart';
import 'review_state.dart';
import 'scheduler.dart';

/// A simple interval ladder scheduler.
///
/// Intervals grow per successful recall. A failed recall resets the interval
/// and records a lapse. There is intentionally no artificial maximum interval,
/// so items can disappear from daily review and later return, as required by
/// `docs/review.md`.
class SimpleScheduler implements Scheduler {
  const SimpleScheduler({
    this.firstInterval = const Duration(days: 1),
    this.baseInterval = const Duration(days: 2),
    this.intervalMultiplier = 2.0,
    this.maximumInterval = const Duration(days: 3650),
  });

  final Duration firstInterval;
  final Duration baseInterval;
  final double intervalMultiplier;
  final Duration maximumInterval;

  Duration _clamp(Duration d) =>
      d.inMilliseconds > maximumInterval.inMilliseconds ? maximumInterval : d;

  @override
  bool isDue(ReviewState state, DateTime now) => state.isDueAt(now);

  @override
  ReviewState schedule({
    required ReviewState previous,
    required ReviewResult result,
    required DateTime now,
  }) {
    if (result.correct) {
      return _scheduleCorrect(previous, now);
    }
    return _scheduleLapse(previous, now);
  }

  ReviewState _scheduleCorrect(ReviewState previous, DateTime now) {
    final reps = previous.repetitionCount + 1;
    // 0 -> 1 day (first recall), then grows: 2, 5, 11, ...
    Duration interval = baseInterval;
    if (reps == 1) {
      interval = firstInterval;
    } else {
      final prior = previous.stability > 0 ? previous.stability : 1.0;
      final next = prior * intervalMultiplier;
      interval = _clamp(Duration(days: next.round()));
    }

    return ReviewState(
      itemId: previous.itemId,
      decisionId: previous.decisionId,
      firstReviewedAt: previous.firstReviewedAt ?? now,
      lastReviewedAt: now,
      nextDueAt: now.add(interval),
      repetitionCount: reps,
      lapseCount: previous.lapseCount,
      stability: interval.inDays.toDouble(),
      difficulty: previous.difficulty,
    );
  }

  ReviewState _scheduleLapse(ReviewState previous, DateTime now) {
    // Reset interval and repetition count; upcoming relearning interval.
    return ReviewState(
      itemId: previous.itemId,
      decisionId: previous.decisionId,
      firstReviewedAt: previous.firstReviewedAt ?? now,
      lastReviewedAt: now,
      nextDueAt: now.add(const Duration(minutes: 10)), // relearning soon
      repetitionCount: 0,
      lapseCount: previous.lapseCount + 1,
      stability: 0,
      difficulty: previous.difficulty,
    );
  }
}