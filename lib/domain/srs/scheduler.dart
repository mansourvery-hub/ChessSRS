import 'review_result.dart';
import 'review_state.dart';

/// Output of the scheduler transition — the new state plus, optionally, the
/// queue/board event used by the UI to show the answer reveal.
class ScheduleOutcome {
  const ScheduleOutcome({
    required this.state,
    this.event,
  });

  final ReviewState state;
  final Object? event;

  ScheduleOutcome copyWith({ReviewState? state, Object? event}) {
    return ScheduleOutcome(state: state ?? this.state, event: event ?? this.event);
  }
}

/// Replaceable scheduling algorithm. The MVP ships a simple interval ladder,
/// but the contract must allow a later FSRS or similar without changing the
/// Review UI or repertoire model.
abstract class Scheduler {
  /// Return whether an item with [state] is due at [now].
  bool isDue(ReviewState state, DateTime now);

  /// Compute the next state after a review answered with [result] at [now].
  ReviewState schedule({
    required ReviewState previous,
    required ReviewResult result,
    required DateTime now,
  });
}