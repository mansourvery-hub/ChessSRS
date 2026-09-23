// Board background: paper squares, ink-hatched dark squares, ink frame.
// Sits UNDER chessground (which must use transparent squares) inside a Stack.
// Adapted from design/flutter/board_background.dart.
import 'package:chess_srs/src/design/hatch.dart';
import 'package:chess_srs/src/design/tokens.dart';
import 'package:flutter/widgets.dart';

class SrsBoardBackgroundPainter extends CustomPainter {
  const SrsBoardBackgroundPainter({required this.colors, this.frame = true});
  final SrsColors colors;
  final bool frame;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final sq = s / 8;

    canvas.drawRect(
      Rect.fromLTWH(0, 0, s, s),
      Paint()..color = colors.squareLight,
    );

    // Dark squares: (file + rowFromTop) is odd. a1 (file 0, row 7) is dark.
    final dark = Path();
    for (var f = 0; f < 8; f++) {
      for (var r = 0; r < 8; r++) {
        if ((f + r).isOdd) dark.addRect(Rect.fromLTWH(f * sq, r * sq, sq, sq));
      }
    }
    canvas.drawPath(dark, Paint()..color = colors.squareDark);

    // Continuous hatch across the whole board, visible only on dark squares.
    canvas.save();
    canvas.clipPath(dark);
    final gap = (s / 100).clamp(4.6, 7.0);
    paintHatch(canvas, Size(s, s), color: colors.hatch, gap: gap, width: 1.1);
    canvas.restore();

    if (frame) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, s, s).inflate(0.75),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = colors.ink,
      );
    }
  }

  @override
  bool shouldRepaint(SrsBoardBackgroundPainter old) => old.colors != colors;
}

/// Static board background widget. Wrap in a RepaintBoundary for performance.
class SrsBoardBackground extends StatelessWidget {
  const SrsBoardBackground({
    super.key,
    required this.size,
    this.frame = true,
  });

  final double size;
  final bool frame;

  @override
  Widget build(BuildContext context) {
    final colors = context.srs;
    return RepaintBoundary(
      child: CustomPaint(
        size: Size.square(size),
        painter: SrsBoardBackgroundPainter(colors: colors, frame: frame),
      ),
    );
  }
}
