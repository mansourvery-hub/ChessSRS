import 'package:equatable/equatable.dart';

/// Outcome of a single review submitted to the scheduler.
class ReviewResult extends Equatable {
  const ReviewResult({required this.correct, this.quality});

  final bool correct;

  /// Optional grade of the answer if the UI offers more than pass/fail.
  final int? quality;

  const ReviewResult.correct({int quality = 5})
      : this(correct: true, quality: quality);

  const ReviewResult.incorrect({int quality = 0})
      : this(correct: false, quality: quality);

  @override
  bool get stringify => true;

  @override
  List<Object?> get props => [correct, quality];
}