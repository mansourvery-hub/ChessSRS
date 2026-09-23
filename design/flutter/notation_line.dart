// "The line is the headline": move numbers + SAN with figurines, and a dashed blank for the answer.
// Each move PAIR is one WidgetSpan so "3." never separates from its move (nowrap), like the prototype.
// REFERENCE IMPLEMENTATION (not compiled by the author).
// Needs `flutter_svg` (or replace SrsFigurine with an icon font built from assets/figurines/*.svg).
import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'chesssrs_tokens.dart';

class SrsFigurine extends StatelessWidget {
  const SrsFigurine(this.kind, {super.key, required this.color, required this.fontSize});
  final String kind; // K Q R B N (no pawn figurine)
  final Color color;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    // Prototype: width .82em, height .96em, sits .12em below the baseline, .03em right margin.
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
      return Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
        SrsFigurine(san[0], color: color, fontSize: style.fontSize ?? 21),
        Text(san.substring(1), style: style),
      ]);
    }
    return Text(san, style: style);
  }
}

class SrsMovePair {
  const SrsMovePair(this.number, this.white, [this.black]);
  final int number;
  final String white;
  final String? black;
}

class SrsNotationLine extends StatelessWidget {
  const SrsNotationLine({
    super.key,
    required this.pairs,
    required this.decisionNumber,
    this.answerSan, // null => show the dashed blank; non-null => the answer, in the accent colour
    required this.fontSize,
  });
  final List<SrsMovePair> pairs; // completed pairs before the decision
  final int decisionNumber;
  final String? answerSan;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final c = context.srs;
    final move = SrsText.lineMove(fontSize, c.ink);
    final number = SrsText.lineNumber(fontSize, c.ink3);
    final gapEm = fontSize * 0.42;

    Widget pairSpan(List<Widget> kids) => Padding(
          padding: EdgeInsets.only(right: gapEm),
          child: Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: kids),
        );

    final spans = <InlineSpan>[
      for (final p in pairs)
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: pairSpan([
            Text('${p.number}.', style: number),
            SizedBox(width: fontSize * 0.22),
            SrsSan(p.white, style: move),
            SizedBox(width: gapEm),
            if (p.black != null) SrsSan(p.black!, style: move),
          ]),
        ),
      WidgetSpan(
        alignment: PlaceholderAlignment.baseline,
        baseline: TextBaseline.alphabetic,
        child: pairSpan([
          Text('$decisionNumber.', style: number),
          SizedBox(width: fontSize * 0.22),
          if (answerSan != null)
            _FillIn(child: SrsSan(answerSan!, style: move.copyWith(color: c.accent)))
          else
            // dashed blank: width 2.3em, height 1.05em, 2px dashed ink3 underline
            SizedBox(
              width: fontSize * 2.3,
              height: fontSize * 1.05,
              child: CustomPaint(painter: _DashedUnderline(c.ink3)),
            ),
        ]),
      ),
    ];
    return Text.rich(TextSpan(children: spans));
  }
}

/// 240 ms fade + 3px rise when the answer fills the blank.
class _FillIn extends StatelessWidget {
  const _FillIn({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: SrsMotion.resolve(context, SrsMotion.fillIn),
        curve: SrsMotion.ease,
        builder: (_, t, c) => Opacity(opacity: t, child: Transform.translate(offset: Offset(0, 3 * (1 - t)), child: c)),
        child: child,
      );
}

class _DashedUnderline extends CustomPainter {
  const _DashedUnderline(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    const dash = 4.0, gap = 3.0; // CSS "dashed" is ~2x thickness; tune against the prototype
    for (double x = 0; x < size.width; x += dash + gap) {
      canvas.drawLine(Offset(x, size.height - 1), Offset((x + dash).clamp(0, size.width).toDouble(), size.height - 1), p);
    }
  }

  @override
  bool shouldRepaint(_DashedUnderline old) => old.color != color;
}
