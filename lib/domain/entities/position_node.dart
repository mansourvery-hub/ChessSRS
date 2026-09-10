import 'package:equatable/equatable.dart';

import 'package:chess_repertoire_srs/core/ids.dart';
import 'package:chess_repertoire_srs/domain/entities/position.dart';
import 'package:chess_repertoire_srs/domain/entities/repertoire_move.dart';

/// A node in the repertoire tree representing a chess position and its move
/// relationships. Each child edge is a move from this position.
class PositionNode extends Equatable {
  const PositionNode({
    required this.id,
    required this.positionKey,
    this.fen = '',
    this.children = const [],
    this.incomingMove,
    this.comment,
  });

  factory PositionNode.create({
    required PositionKey positionKey,
    String? fen,
    PositionNode? parent,
    RepertoireMove? incomingMove,
    String? comment,
  }) {
    final resolvedFen = fen ?? positionKey.fen;
    return PositionNode(
      id: uuid.v4(),
      positionKey: positionKey,
      fen: resolvedFen,
      incomingMove: incomingMove,
      comment: comment,
      children: const [],
    );
  }

  final String id;

  final PositionKey positionKey;

  final String fen;

  final RepertoireMove? incomingMove;

  final String? comment;

  final List<PositionNode> children;

  bool get isLeaf => children.isEmpty;

  PositionNode addChild(PositionNode child) {
    return PositionNode(
      id: id,
      positionKey: positionKey,
      fen: fen,
      incomingMove: incomingMove,
      comment: comment,
      children: [...children, child],
    );
  }

  PositionNode? childForMove(RepertoireMove move) {
    for (final child in children) {
      if (child.incomingMove?.from == move.from && child.incomingMove?.to == move.to && child.incomingMove?.promotion == move.promotion) {
        return child;
      }
    }
    return null;
  }

  List<RepertoireMove> get childMoves => children.map((c) => c.incomingMove!).toList();

  @override
  bool get stringify => true;

  @override
  List<Object?> get props => [id, positionKey, incomingMove, children, comment];
}