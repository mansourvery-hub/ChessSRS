import 'package:flutter/material.dart';
import 'package:chess/chess.dart' as chess;
import 'package:chess_repertoire_srs/ui/board/piece_images.dart';
import 'package:chess_repertoire_srs/ui/board/coordinates.dart';

/// Chess piece widget with drag support
/// Ported from chessrs ChessPiece.tsx
class ChessPiece extends StatelessWidget {
  final int type; // chess.PieceType value (0-5)
  final chess.Color color;
  final double size;
  final String position; // algebraic notation e.g. "e4"
  final chess.Chess game;
  final VoidCallback onDragStart;

  const ChessPiece({
    super.key,
    required this.type,
    required this.color,
    required this.size,
    required this.position,
    required this.game,
    required this.onDragStart,
  });

  @override
  Widget build(BuildContext context) {
    final assetPath = PieceImages.assetPath(type, color);

    return Draggable<String>(
      data: position,
      feedback: Material(
        elevation: 8,
        color: Colors.transparent,
        child: _buildPiece(),
      ),
      childWhenDragging: Container(
        width: size,
        height: size,
        color: Colors.transparent,
      ),
      onDragStarted: () {
        onDragStart();
      },
      child: DragTarget<String>(
        builder: (context, candidateData, rejectedData) {
          return Container(
            width: size,
            height: size,
            child: Image.asset(
              PieceImages.assetPath(type, color),
              width: size,
              height: size,
              fit: BoxFit.contain,
            ),
          );
        },
        onAcceptWithDetails: (details) {},
        onWillAccept: (data) => true,
      ),
    );
  }

  Widget _buildPiece() {
    final assetPath = PieceImages.assetPath(type, color);
    return Image.asset(
      assetPath,
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }
}

/// Piece type enum for UI layer (maps to chess.PieceType values)
enum PieceType {
  king,
  queen,
  rook,
  bishop,
  knight,
  pawn,
}

/// Piece color enum for UI layer
enum PieceColor { white, black }