import 'package:equatable/equatable.dart';

/// Immutable historical record of one review outcome. Kept long enough to
/// debug/reconstruct scheduling behaviour.
class ReviewEvent extends Equatable {
  const ReviewEvent({
    required this.itemId,
    required this.decisionId,
    required this.when,
    required this.outcome,
    required this.interval,
    required this.oldState,
    required this.newState,
  });

  final String itemId;

  final String decisionId;

  final DateTime when;

  final bool outcome;

  final Duration interval;

  final Map<String, Object?> oldState;

  final Map<String, Object?> newState;

  @override
  bool get stringify => true;

  @override
  List<Object?> get props =>
      [itemId, decisionId, when, outcome, interval, oldState, newState];
}