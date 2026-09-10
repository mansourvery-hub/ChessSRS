import 'package:equatable/equatable.dart';

/// Current SRS state for one review item.
class ReviewState extends Equatable {
  const ReviewState({
    required this.itemId,
    required this.decisionId,
    this.firstReviewedAt,
    this.lastReviewedAt,
    this.nextDueAt,
    this.repetitionCount = 0,
    this.lapseCount = 0,
    this.stability = 0,
    this.difficulty = 0,
  });

  factory ReviewState.initial({required String itemId, required String decisionId}) =>
      ReviewState(itemId: itemId, decisionId: decisionId);

  final String itemId;

  final String decisionId;

  final DateTime? firstReviewedAt;

  final DateTime? lastReviewedAt;

  final DateTime? nextDueAt;

  /// Number of successful recalls (streak or lifetime depending on scheduler).
  final int repetitionCount;

  final int lapseCount;

  /// Stability / interval growth factor used by the scheduler.
  final double stability;

  final double difficulty;

  bool get isDue => nextDueAt == null || nextDueAt!.isBefore(DateTime.now());

  bool get isNew => repetitionCount == 0 && nextDueAt == null;

  bool get isLearned => repetitionCount > 0 && stability > 0;

  /// True when review is scheduled to be due now.
  bool isDueAt(DateTime now) => nextDueAt == null || !nextDueAt!.isAfter(now);

  @override
  bool get stringify => true;

  @override
  List<Object?> get props => [
        itemId,
        decisionId,
        firstReviewedAt,
        lastReviewedAt,
        nextDueAt,
        repetitionCount,
        lapseCount,
        stability,
        difficulty,
      ];
}