import 'package:chess_repertoire_srs/chess/chess_service.dart';
import 'package:chess_repertoire_srs/chess/pgn_parser.dart' as pgn_parser;
import 'package:chess/chess.dart' as ch;
import 'package:chess_repertoire_srs/core/ids.dart';
import 'package:chess_repertoire_srs/domain/entities/position_node.dart';
import 'package:chess_repertoire_srs/domain/entities/repertoire_move.dart';
import 'package:chess_repertoire_srs/domain/entities/position.dart';

/// Converts parsed PGN tree into domain PositionNode structure using ChessService.
class PgnConverter {
  const PgnConverter({required this.chess});

  final ChessService chess;

  /// Convert a parsed PgnNode tree into a PositionNode root with children.
  PositionNode? convertTree(
    pgn_parser.PgnNode tree,
    String studyId,
    String title, {
    String? startingFen,
    List<String>? errors,
  }) {
    try {
      final c = startingFen != null
          ? chess.fromFen(startingFen)
          : chess.fromFen(chess.initialFenValue);

      if (c == null) {
        if (errors != null) {
          errors.add('Invalid starting FEN: $startingFen');
        }
        return null;
      }

      return _buildNode(tree, c, studyId, 'root', null, null, errors: errors);
    } catch (e) {
      if (errors != null) {
        errors.add(e.toString());
      }
      return null;
    }
  }

  PositionNode? _buildNode(
    pgn_parser.PgnNode pgnNode,
    ch.Chess c,
    String studyId,
    String nodeId,
    RepertoireMove? incomingMove,
    String? comment, {
    List<String>? errors,
  }) {
    final positionKey = PositionKey.fromFen(c.fen);
    final children = <PositionNode>[];

    for (final childPgnNode in pgnNode.children) {
      final child = _buildChild(childPgnNode, c, studyId, errors: errors);
      if (child != null) {
        children.add(child);
      }
    }

    return PositionNode(
      id: uuid.v4(),
      positionKey: positionKey,
      fen: c.fen,
      children: children,
      incomingMove: incomingMove,
      comment: comment,
    );
  }

  PositionNode? _buildChild(
    pgn_parser.PgnNode pgnNode,
    ch.Chess c,
    String studyId, {
    List<String>? errors,
  }) {
    final move = chess.resolveSan(c.fen, pgnNode.san);
    if (move == null) {
      if (errors != null) {
        errors.add('Illegal SAN move: ${pgnNode.san}');
      }
      return null;
    }

    final moveRepertoire = RepertoireMove(
      from: move.from,
      to: move.to,
      promotion: move.promotion,
      san: move.san,
    );

    c.move(move.san);
    final child = _buildNode(
      pgnNode,
      c,
      studyId,
      pgnNode.san,
      moveRepertoire,
      pgnNode.comment,
      errors: errors,
    );
    c.undo();

    return child;
  }
}