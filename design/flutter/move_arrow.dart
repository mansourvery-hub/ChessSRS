// The correction "pen stroke" arrow: a gently bowed curve with a small triangular head.
// Draws in over 260 ms; the head fades in from 170 ms. Never blocks board input (IgnorePointer).
// REFERENCE IMPLEMENTATION (not compiled by the author). Geometry mirrors showArrow() in prototype.js.
import 'dart:ui' show PathMetric;
import 'package:flutter/widgets.dart';
import 'chesssrs_tokens.dart';

class SrsMoveArrow extends StatelessWidget {
  const SrsMoveArrow({
    super.key,
    required this.from,
    required this.to,
    this.whiteAtBottom = true,
  });
  final String from; // e.g. 'b1'
  final String to; // e.g. 'c3'
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
            painter: _ArrowPainter(from, to, color, t, whiteAtBottom, duration == Duration.zero),
          ),
        ),
      ),
    );
  }
}

class _ArrowPainter extends CustomPainter {
  _ArrowPainter(this.from, this.to, this.color, this.t, this.white, this.instant);
  final String from, to;
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
    return Offset(f * 10 + 5.0, row * 10 + 5.0); // board = 80 units, square = 10 units
  }

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 80;
    canvas.scale(k);

    final a = _centre(from), b = _centre(to);
    final d = b - a;
    final len = d.distance;
    final nx = -d.dy / len, ny = d.dx / len;
    final bow = len * 0.13;
    final ctrl = Offset((a.dx + b.dx) / 2 + nx * bow, (a.dy + b.dy) / 2 + ny * bow);

    var tan = b - ctrl;
    tan = tan / tan.distance; // tangent at the end of the curve
    const head = 3.3, halfW = 1.8, tipInset = 0.9;
    final tip = b - tan * tipInset;
    final baseC = tip - tan * head;
    final h1 = Offset(baseC.dx - tan.dy * halfW, baseC.dy + tan.dx * halfW);
    final h2 = Offset(baseC.dx + tan.dy * halfW, baseC.dy - tan.dx * halfW);

    final alpha = 0.88;
    final path = Path()
      ..moveTo(a.dx, a.dy)
      ..quadraticBezierTo(ctrl.dx, ctrl.dy, baseC.dx, baseC.dy);

    final line = Paint()
      ..color = color.withValues(alpha: alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    final PathMetric metric = path.computeMetrics().first;
    canvas.drawPath(metric.extractPath(0, metric.length * t), line);

    // head: starts at 170 ms, fades in over 120 ms (of a 260 ms tween)
    final ms = t * 260;
    final headT = instant ? 1.0 : ((ms - 170) / 120).clamp(0.0, 1.0).toDouble();
    if (headT > 0) {
      final headPath = Path()
        ..moveTo(tip.dx, tip.dy)
        ..lineTo(h1.dx, h1.dy)
        ..lineTo(h2.dx, h2.dy)
        ..close();
      canvas.drawPath(
          headPath,
          Paint()
            ..color = color.withValues(alpha: alpha * headT)
            ..style = PaintingStyle.fill);
    }
  }

  @override
  bool shouldRepaint(_ArrowPainter old) =>
      old.t != t || old.from != from || old.to != to || old.color != color || old.white != white;
}
