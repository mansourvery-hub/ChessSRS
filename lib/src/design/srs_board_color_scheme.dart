// Transparent ChessboardColorScheme for chessground.
// The hatched background is painted by SrsBoardBackground underneath;
// chessground draws transparent squares so the background shows through.
import 'package:chess_srs/src/design/tokens.dart';
import 'package:chessground/chessground.dart';
import 'package:flutter/widgets.dart';

ChessboardColorScheme srsBoardColorScheme(SrsColors c) {
  return ChessboardColorScheme(
    lightSquare: const Color(0x00000000),
    darkSquare: const Color(0x00000000),
    background: _TransparentBackground(
      lightSquare: c.squareLight,
      darkSquare: c.squareDark,
    ),
    whiteCoordBackground: _TransparentBackground(
      lightSquare: c.squareLight,
      darkSquare: c.squareDark,
    ),
    blackCoordBackground: _TransparentBackground(
      lightSquare: c.squareLight,
      darkSquare: c.squareDark,
    ),
    lastMove: HighlightDetails(solidColor: c.accentSoft),
    selected: HighlightDetails(solidColor: c.accentMid),
    validMoves: c.accent.withValues(alpha: 0.28),
    validPremoves: c.accent.withValues(alpha: 0.18),
  );
}

class _TransparentBackground extends ChessboardBackground {
  const _TransparentBackground({
    required super.lightSquare,
    required super.darkSquare,
  });

  @override
  Widget build(BuildContext context) {
    return const SizedBox.expand();
  }
}
