// Correction "pen stroke" arrow: a gently bowed curve with a triangular head.
// Adapted from design/flutter/move_arrow.dart.
import 'package:chess_srs/src/design/tokens.dart';
import 'package:flutter/widgets.dart';

class SrsMoveArrow extends StatelessWidget {
  const SrsMoveArrow({
    super.key,
    required this.from,
    required this.to,
    this.whiteAtBottom = true,
  });
  final String from;
  final String to;
  final bool whiteAtBottom;

  @override
  Widget build(BuildContext context) {
    final color = context.srs.accent;
    final duration = SrsMotion.resolve(context, SrsMotion.arrowDraw);
    return IgnorePointer(
      child: TweenAnimationBuilder<double>(
        key: ValueKey('$from$to$whiteAtBottom'),
        tween: Tween(begin: 0, end: 1),
        duration: duration,
        curve: SrsMotion.ease,
        builder: (context, t, _) => SizedBox.expand(
          child: CustomPaint(
            painter: _ArrowPainter(
              from,
              to,
              color,
              t,
              whiteAtBottom,
              duration == Duration.zero,
            ),
          ),
        ),
      ),
    );
  }
}

class _ArrowPainter extends CustomPainter {
  _ArrowPainter(
    this.from,
    this.to,
    this.color,
    this.t,
    this.white,
    this.instant,
  );
  final String from;
  final String to;
  final Color color;
  final double t;
  final bool white;
  final bool instant;

  Offset _centre(String sq) {
    var f = sq.codeUnitAt(0) - 97; // a=0
    var row = 8 - int.parse(sq.substring(1)); // rank 8 is row 0
    if (!white) {
      f = 7 - f;
      row = 7 - row;
    }
    return Offset(f + 0.5, row + 0.5);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0) return;
    final s = size.shortestSide;
    final u = s / 8; // one square in pixels

    final a = _centre(from) * u;
    final b = _centre(to) * u;
    final mid = (a + b) / 2;
    final dx = b.dx - a.dx;
    final dy = b.dy - a.dy;
    final dist = Offset(dx, dy).distance;
    final perp = Offset(-dy, dx) / dist;
    final bow = 0.13 * dist;
    final ctrl = mid + perp * bow;

    // Head geometry (in board units then scaled to pixels).
    const headLen = 3.3;
    const headHalf = 1.8;
    const tipInset = 0.9;

    // Quadratic Bézier path.
    final path = Path()
      ..moveTo(a.dx, a.dy)
      ..quadraticBezierTo(ctrl.dx, ctrl.dy, b.dx, b.dy);

    // Compute the path metrics for partial drawing.
    final metric = path.computeMetrics().first;
    final totalLen = metric.length;

    // The tip is inset from the destination centre.
    final tipDist = totalLen - tipInset * (s / 80);
    final headBaseDist = tipDist - headLen * (s / 80);

    // Draw the stroke up to the head base.
    final strokeEnd = headBaseDist * t;
    final partial = metric.extractPath(0, strokeEnd.clamp(0, totalLen));
    canvas.drawPath(
      partial,
      Paint()
        ..color = color.withValues(alpha: 0.88)
        ..strokeWidth = 1.2 * (s / 80)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..isAntiAlias = true,
    );

    // Head: fade in from 170/260 of the animation.
    final headT =
        instant ? 1.0 : ((t - 170 / 260) / (120 / 260)).clamp(0, 1);
    if (headT <= 0) return;

    final tipTangent = metric.getTangentForOffset(tipDist)!;
    final tip = tipTangent.position;
    final dir = tipTangent.vector;
    final perpH = Offset(-dir.dy, dir.dx);
    final baseP = tip - dir * (headLen * (s / 80));
    final left = baseP + perpH * (headHalf * (s / 80));
    final right = baseP - perpH * (headHalf * (s / 80));

    final headPath = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(left.dx, left.dy)
      ..lineTo(right.dx, right.dy)
      ..close();
    canvas.drawPath(
      headPath,
      Paint()
        ..color = color.withValues(alpha: 0.88 * headT.toDouble())
        ..style = PaintingStyle.fill
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(_ArrowPainter old) =>
      old.from != from ||
      old.to != to ||
      old.color != color ||
      old.t != t ||
      old.white != white;
}
