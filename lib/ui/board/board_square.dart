import 'package:flutter/material.dart';
import 'package:chess/chess.dart' as chess;
import 'package:chess_repertoire_srs/ui/board/piece_images.dart';
import 'package:chess_repertoire_srs/ui/board/coordinates.dart';

/// A square on the chess board
/// Ported from chessrs BoardSquare.tsx
@immutable
class ChessSquare extends StatelessWidget {
  final int x; // file 0-7 (a-h)
  final int y; // rank 0-7 (1-8 from white perspective)
  final int? pieceType;
  final chess.Color? pieceColor;
  final chess.Chess game;
  final double size;
  final String? lastMoveUci;
  final String? selectedSquare;
  final bool boardEnabled;
  final void Function(String square) onSquareTap;
  final void Function(String from, String to) onMove;

  const ChessSquare({
    super.key,
    required this.x,
    required this.y,
    this.pieceType,
    this.pieceColor,
    required this.game,
    required this.size,
    this.lastMoveUci,
    this.selectedSquare,
    this.boardEnabled = true,
    required this.onSquareTap,
    required this.onMove,
  });

  @override
  Widget build(BuildContext context) {
    final square = squareIndexToCoordinates(x, y);
    final piece = game.get(square);
    final effectivePieceType = piece?.type?.shift ?? pieceType ?? 5; // default to pawn
    final effectivePieceColor = piece?.color ?? pieceColor;

    final isDark = (x + y) % 2 == 1;
    final isSelected = selectedSquare == square;
    final isLastMove = lastMoveUci != null &&
        (lastMoveUci!.substring(0, 2) == square ||
         lastMoveUci!.substring(2, 4) == square);

    Color squareColor;
    if (isSelected) {
      squareColor = const Color(0xFFBACA44);
    } else if (isLastMove) {
      squareColor = isDark ? const Color(0xFF769656) : const Color(0xFFCED26B);
    } else {
      squareColor = isDark ? const Color(0xFF769656) : const Color(0xFFEEEED2);
    }

    if (isSelected) {
      squareColor = const Color(0xFFBACA44);
    }

    final pieceWidget = (effectivePieceType != null && effectivePieceColor != null)
        ? Image.asset(
            PieceImages.assetPath(effectivePieceType, effectivePieceColor!),
            width: size * 0.9,
            height: size * 0.9,
            fit: BoxFit.contain,
          )
        : const SizedBox.shrink();

    return GestureDetector(
      onTap: boardEnabled ? () => onSquareTap(square) : null,
      child: Container(
        width: size,
        height: size,
        color: squareColor,
        child: Stack(
          alignment: Alignment.center,
          children: [
            pieceWidget,
            // Valid move indicator for empty squares
            if (selectedSquare != null && selectedSquare != square)
              Center(
                child: Container(
                  width: size * 0.3,
                  height: size * 0.3,
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            // Valid move indicator for captures
            if (selectedSquare != null && selectedSquare != square &&
                pieceType != null)
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.green, width: 3),
                ),
              ),
            pieceWidget,
          ],
        ),
      ),
    );
  }
}