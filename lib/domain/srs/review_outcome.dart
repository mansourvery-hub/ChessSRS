import 'package:equatable/equatable.dart';
import 'package:chess_repertoire_srs/domain/entities/repertoire_move.dart';

/// The outcome of a review step: whether the answer was correct and any feedback.
class ReviewOutcome extends Equatable {
  const ReviewOutcome({
    required this.correct,
    this.expectedMove,
  });

  final bool correct;
  final RepertoireMove? expectedMove;

  @override
  bool get stringify => true;

  @override
  List<Object?> get props => [correct, expectedMove];
}