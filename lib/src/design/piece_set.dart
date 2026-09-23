// Bespoke ChessSRS piece set. Maps PieceKind → AssetImage for chessground.
// Light/dark variants use different assets for visibility on the respective
// board colours.
import 'package:chessground/chessground.dart' show PieceAssets;
import 'package:dartchess/dartchess.dart' show PieceKind;
import 'package:flutter/widgets.dart' show AssetImage;

const _base = 'assets/pieces';

PieceAssets srsPieceAssets({required bool dark}) {
  final sub = dark ? 'dark' : 'light';
  final path = '$_base/$sub/png-512';
  return {
    PieceKind.whitePawn: AssetImage('$path/wP.png'),
    PieceKind.whiteKnight: AssetImage('$path/wN.png'),
    PieceKind.whiteBishop: AssetImage('$path/wB.png'),
    PieceKind.whiteRook: AssetImage('$path/wR.png'),
    PieceKind.whiteQueen: AssetImage('$path/wQ.png'),
    PieceKind.whiteKing: AssetImage('$path/wK.png'),
    PieceKind.blackPawn: AssetImage('$path/bP.png'),
    PieceKind.blackKnight: AssetImage('$path/bN.png'),
    PieceKind.blackBishop: AssetImage('$path/bB.png'),
    PieceKind.blackRook: AssetImage('$path/bR.png'),
    PieceKind.blackQueen: AssetImage('$path/bQ.png'),
    PieceKind.blackKing: AssetImage('$path/bK.png'),
  };
}
