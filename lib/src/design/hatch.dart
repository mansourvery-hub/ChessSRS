// Shared 45-degree hatch used by the board (dark squares) and the memory bar.
// Lines run bottom-left to top-right ("/"), like the prototype.
// Adapted from design/flutter/hatch.dart.
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Paints parallel "/" lines spaced [gap] apart (perpendicular distance).
void paintHatch(
  Canvas canvas,
  Size size, {
  required Color color,
  required double gap,
  required double width,
}) {
  final paint = Paint()
    ..color = color
    ..strokeWidth = width
    ..style = PaintingStyle.stroke
    ..isAntiAlias = true;
  const n = Offset(0.7071067811865476, 0.7071067811865476);
  const d = Offset(-0.7071067811865476, 0.7071067811865476);
  final reach = math.sqrt(size.width * size.width + size.height * size.height);
  for (double c = width / 2; c <= reach + gap; c += gap) {
    final base = n * c;
    canvas.drawLine(base - d * reach, base + d * reach, paint);
  }
}

class HatchPainter extends CustomPainter {
  const HatchPainter({required this.color, required this.gap, required this.width});
  final Color color;
  final double gap;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    paintHatch(canvas, size, color: color, gap: gap, width: width);
  }

  @override
  bool shouldRepaint(HatchPainter old) =>
      old.color != color || old.gap != gap || old.width != width;
}
