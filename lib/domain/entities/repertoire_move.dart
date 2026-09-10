import 'package:equatable/equatable.dart';

/// A legal chess move as stored in the repertoire tree.
///
/// The fields mirror what the training engine needs to validate a player's
/// submission without depending on any external chess package.
class RepertoireMove extends Equatable {
  const RepertoireMove({
    required this.from,
    required this.to,
    this.promotion,
    this.san = '',
  });

  final String from;

  final String to;

  final String? promotion;

  final String san;

  const RepertoireMove.fromAlgebraic(String from, String to, {String? promotion})
      : this(from: from, to: to, promotion: promotion);

  String get uci => promotion != null ? '$from$to$promotion' : '$from$to';

  @override
  bool get stringify => true;

  @override
  List<Object?> get props => [from, to, promotion, san];
}