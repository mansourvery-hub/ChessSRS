import 'package:flutter/material.dart';
import 'package:chess/chess.dart' as chess;
import 'package:chess_repertoire_srs/ui/board/board_square.dart';
import 'package:chess_repertoire_srs/ui/board/coordinates.dart';

/// Main chessboard widget
/// Ported from chessrs Chessboard.tsx
@immutable
class Chessboard extends StatelessWidget {
  final chess.Chess game;
  final String fen;
  final String perspective; // 'white' or 'black'
  final String? selectedSquare;
  final String? lastMoveUci;
  final bool boardEnabled;
  final void Function(String square) onSquareTap;
  final void Function(String from, String to) onMove;
  final double? size;

  const Chessboard({
    super.key,
    required this.game,
    required this.fen,
    this.perspective = 'white',
    this.selectedSquare,
    this.lastMoveUci,
    this.boardEnabled = true,
    required this.onSquareTap,
    required this.onMove,
    this.size,
  });

  @override
  Widget build(BuildContext context) {
    final boardSize = size ?? MediaQuery.of(context).size.width * 0.9;
    final squareSize = boardSize / 8;

    return Center(
      child: Container(
        width: boardSize,
        height: boardSize,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black45, width: 2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: _buildBoard(squareSize: boardSize / 8),
      ),
    );
  }

  Widget _buildBoard({required double squareSize}) {
    final ranks = perspective == 'white'
        ? List.generate(8, (i) => 7 - i) // 7,6,5,4,3,2,1,0 (white at bottom)
        : List.generate(8, (i) => i); // 0,1,2,3,4,5,6,7 (black at bottom)

    final files = perspective == 'white'
        ? List.generate(8, (i) => i) // a,b,c,d,e,f,g,h (left to right for white)
        : List.generate(8, (i) => 7 - i); // h,g,f,e,d,c,b,a (left to right for black)

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: ranks.map<Widget>((rank) {
        final files = perspective == 'white'
            ? List.generate(8, (i) => i)
            : List.generate(8, (i) => 7 - i);

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: files.map<Widget>((file) {
            final square = squareIndexToCoordinates(file, rank);
            final piece = game.get(square);

            return ChessSquare(
              key: ValueKey(square),
              x: file,
              y: rank,
              pieceType: piece?.type.shift,
              pieceColor: piece?.color,
              game: chess.Chess()..load(fen), // Fresh instance per square
              size: squareSize,
              lastMoveUci: lastMoveUci,
              selectedSquare: selectedSquare,
              boardEnabled: boardEnabled,
              onSquareTap: onSquareTap,
              onMove: onMove,
            );
          }).toList(),
        );
      }).toList(),
    );
  }
}