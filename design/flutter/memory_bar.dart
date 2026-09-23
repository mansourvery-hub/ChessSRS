// Three-state memory bar. Encoded by SHAPE, never by colour alone:
//   retained = solid ink, learning = ink hatch, new = empty with a 1px outline.
// REFERENCE IMPLEMENTATION (not compiled by the author).
import 'package:flutter/widgets.dart';
import 'chesssrs_tokens.dart';
import 'hatch.dart';

class SrsMemoryBar extends StatelessWidget {
  const SrsMemoryBar({
    super.key,
    required this.retained,
    required this.learning,
    required this.fresh,
    this.height = 5, // 5 in lists, 10 on the "Nothing due" screen
    this.gap = 2, // 2 in lists, 3 on the "Nothing due" screen
    this.radius = 1, // 1 in lists, 2 on the "Nothing due" screen
    this.width,
  });
  final int retained, learning, fresh;
  final double height, gap, radius;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final c = context.srs;
    final r = BorderRadius.circular(radius);
    final segs = <Widget>[
      if (retained > 0)
        Expanded(flex: retained, child: DecoratedBox(decoration: BoxDecoration(color: c.ink, borderRadius: r))),
      if (learning > 0)
        Expanded(
          flex: learning,
          child: ClipRRect(
            borderRadius: r,
            child: CustomPaint(
              painter: HatchPainter(color: c.ink, gap: 3.2, width: 1.2),
              child: const SizedBox.expand(),
            ),
          ),
        ),
      if (fresh > 0)
        Expanded(
          flex: fresh,
          child: DecoratedBox(
            decoration: BoxDecoration(borderRadius: r, border: Border.all(color: c.ink3, width: 1)),
          ),
        ),
    ];
    final withGaps = <Widget>[];
    for (var i = 0; i < segs.length; i++) {
      if (i > 0) withGaps.add(SizedBox(width: gap));
      withGaps.add(segs[i]);
    }
    return Semantics(
      label: '$retained retained, $learning learning, $fresh new',
      child: ExcludeSemantics(
        child: SizedBox(width: width, height: height, child: Row(children: withGaps)),
      ),
    );
  }
}
