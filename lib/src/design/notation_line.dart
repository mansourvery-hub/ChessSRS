// Notation line: move numbers + SAN with figurines, and a dashed blank.
// Each move PAIR is one WidgetSpan so numbers never wrap away from their move.
// Adapted from design/flutter/notation_line.dart.
// Uses flutter_svg for figurines.
import 'package:chess_srs/src/design/tokens.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

class SrsFigurine extends StatelessWidget {
  const SrsFigurine(
    this.kind, {
    super.key,
    required this.color,
    required this.fontSize,
  });
  final String kind; // K Q R B N (no pawn figurine)
  final Color color;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(right: fontSize * 0.03),
      child: Transform.translate(
        offset: Offset(0, fontSize * 0.12),
        child: SvgPicture.asset(
          'assets/figurines/$kind.svg',
          width: fontSize * 0.82,
          height: fontSize * 0.96,
          colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
        ),
      ),
    );
  }
}

/// One SAN token: replaces a leading piece letter with its figurine.
class SrsSan extends StatelessWidget {
  const SrsSan(this.san, {super.key, required this.style});
  final String san;
  final TextStyle style;

  static const _pieces = 'KQRBN';

  @override
  Widget build(BuildContext context) {
    final color = style.color ?? const Color(0xFF000000);
    if (san.isNotEmpty && _pieces.contains(san[0])) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SrsFigurine(san[0], color: color, fontSize: style.fontSize ?? 16),
          Text(san.substring(1), style: style),
        ],
      );
    }
    return Text(san, style: style);
  }
}

/// The dashed blank that represents the answer slot.
class SrsDashedBlank extends StatelessWidget {
  const SrsDashedBlank({super.key, required this.fontSize});
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final c = context.srs;
    return SizedBox(
      width: fontSize * 2.3,
      height: fontSize * 1.05,
      child: CustomPaint(
        painter: _DashPainter(color: c.ink3),
      ),
    );
  }
}

class _DashPainter extends CustomPainter {
  const _DashPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;
    const dashLen = 6.0;
    const gapLen = 4.0;
    final y = size.height - 1;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(
        Offset(x, y),
        Offset((x + dashLen).clamp(0, size.width), y),
        paint,
      );
      x += dashLen + gapLen;
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) => old.color != color;
}

/// Builds a notation line from a list of moves.
class SrsNotationLine extends StatelessWidget {
  const SrsNotationLine({
    super.key,
    required this.moves,
    this.currentPly,
    this.showBlank = false,
    this.wide = false,
    this.wideWidth = 0,
  });

  /// List of SAN strings, starting from ply 0 (White's first move).
  final List<String> moves;

  /// The ply index of the current position (0-based). Null = show all.
  final int? currentPly;

  /// Whether to show a dashed blank at the end.
  final bool showBlank;

  final bool wide;
  final double wideWidth;

  @override
  Widget build(BuildContext context) {
    final c = context.srs;
    final size = SrsText.lineSize(wide: wide, wideWidth: wideWidth);
    final moveStyle = SrsText.lineMove(size, c.ink);
    final numStyle = SrsText.lineNumber(size, c.ink3);

    final spans = <InlineSpan>[];
    for (var i = 0; i < moves.length; i += 2) {
      final moveNum = (i ~/ 2) + 1;
      if (spans.isNotEmpty) {
        spans.add(TextSpan(text: '  ', style: moveStyle));
      }

      // Build a pair: "N. white black"
      final pairChildren = <InlineSpan>[
        TextSpan(text: '$moveNum.', style: numStyle),
        const WidgetSpan(child: SizedBox(width: 3)),
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: SrsSan(moves[i], style: moveStyle),
        ),
      ];

      if (i + 1 < moves.length) {
        pairChildren.addAll([
          const WidgetSpan(child: SizedBox(width: 6)),
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: SrsSan(moves[i + 1], style: moveStyle),
          ),
        ]);
      }

      spans.add(
        WidgetSpan(
          child: RichText(
            text: TextSpan(children: pairChildren),
          ),
        ),
      );
    }

    if (showBlank) {
      if (spans.isNotEmpty) {
        spans.add(TextSpan(text: '  ', style: moveStyle));
      }
      // Add the move number for the blank.
      final blankNum = (moves.length ~/ 2) + 1;
      final isBlackTurn = moves.length.isOdd;
      spans.add(
        WidgetSpan(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isBlackTurn) Text('$blankNum.', style: numStyle),
              if (!isBlackTurn) const SizedBox(width: 3),
              if (isBlackTurn) Text('$blankNum...', style: numStyle),
              if (isBlackTurn) const SizedBox(width: 3),
              SrsDashedBlank(fontSize: size),
            ],
          ),
        ),
      );
    }

    return Text.rich(
      TextSpan(children: spans),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}
