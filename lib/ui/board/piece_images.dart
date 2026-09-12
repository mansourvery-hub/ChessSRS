/// Piece image mapping and utilities, ported from chessrs getImageByPiece.ts

import 'package:chess/chess.dart' as chess;
import 'package:flutter/services.dart';

/// Maps our internal piece representation to asset paths
class PieceImages {
  static const Map<int, String> _whitePieceNames = {
    0: 'whiteKing',     // chess.PieceType.king
    1: 'whiteQueen',    // chess.PieceType.queen
    2: 'whiteRook',     // chess.PieceType.rook
    3: 'whiteBishop',   // chess.PieceType.bishop
    4: 'whiteKnight',   // chess.PieceType.knight
    5: 'whitePawn',     // chess.PieceType.pawn
  };

  static const Map<int, String> _blackPieceNames = {
    0: 'blackKing',     // chess.PieceType.king
    1: 'blackQueen',    // chess.PieceType.queen
    2: 'blackRook',     // chess.PieceType.rook
    3: 'blackBishop',   // chess.PieceType.bishop
    4: 'blackKnight',   // chess.PieceType.knight
    5: 'blackPawn',     // chess.PieceType.pawn
  };

  /// Returns the asset name (without extension) for a given piece type and color
  static String pieceName(int type, chess.Color color) {
    final names = color == chess.Color.WHITE ? _whitePieceNames : _blackPieceNames;
    return names[type]!;
  }

  /// Returns the full asset path for a piece
  static String assetPath(int type, chess.Color color) {
    return 'assets/pieces/${pieceName(type, color)}.svg';
  }

  /// Returns the asset path for a piece given by our internal RepertoireMove
  static String assetPathFromMove({
    required String pieceType, // 'k', 'q', 'r', 'b', 'n', 'p'
    required String color, // 'w' or 'b'
  }) {
    final pieceMap = <String, String>{
      'k': 'king',
      'q': 'queen',
      'r': 'rook',
      'b': 'bishop',
      'n': 'knight',
      'p': 'pawn',
    };
    final colorPrefix = color == 'w' ? 'white' : 'black';
    final pieceName = pieceMap[pieceType.toLowerCase()]!;
    return 'assets/pieces/${colorPrefix}${pieceName[0].toUpperCase()}${pieceName.substring(1)}.svg';
  }

  /// Preloads all piece images for faster rendering
  static Future<void> preloadAll(AssetBundle bundle) async {
    const pieceNames = [
      'whiteKing', 'whiteQueen', 'whiteRook', 'whiteBishop', 'whiteKnight', 'whitePawn',
      'blackKing', 'blackQueen', 'blackRook', 'blackBishop', 'blackKnight', 'blackPawn',
    ];
    for (final name in pieceNames) {
      await bundle.load('assets/pieces/$name.svg');
    }
  }
}