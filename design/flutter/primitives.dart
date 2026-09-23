// Minimal, Material-free primitives: pill button, text button, segmented control, switch, accent dots.
// Only package:flutter/widgets.dart. REFERENCE IMPLEMENTATION (not compiled by the author).
// Every interactive element: min 44dp hit target, keyboard activation (Enter/Space), 2px accent
// focus ring offset 2px, and Semantics(button/toggled).
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'chesssrs_tokens.dart';

class SrsPressable extends StatefulWidget {
  const SrsPressable({
    super.key,
    required this.onPressed,
    required this.builder,
    this.semanticLabel,
    this.radius = 999,
    this.pressScale = 1,
    this.semanticsToggled,
  });
  final VoidCallback? onPressed;
  final Widget Function(BuildContext context, bool hovered, bool pressed) builder;
  final String? semanticLabel;
  final double radius;
  final double pressScale; // 0.97 for the pill button
  final bool? semanticsToggled;

  @override
  State<SrsPressable> createState() => _SrsPressableState();
}

class _SrsPressableState extends State<SrsPressable> {
  bool _hover = false, _down = false, _focus = false;

  @override
  Widget build(BuildContext context) {
    final c = context.srs;
    final enabled = widget.onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      toggled: widget.semanticsToggled,
      label: widget.semanticLabel,
      child: FocusableActionDetector(
        enabled: enabled,
        mouseCursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
        onShowHoverHighlight: (v) => setState(() => _hover = v),
        onShowFocusHighlight: (v) => setState(() => _focus = v),
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) {
            widget.onPressed?.call();
            return null;
          }),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: enabled ? (_) => setState(() => _down = true) : null,
          onTapCancel: () => setState(() => _down = false),
          onTapUp: (_) => setState(() => _down = false),
          onTap: widget.onPressed,
          child: Stack(clipBehavior: Clip.none, children: [
            AnimatedScale(
              scale: _down ? widget.pressScale : 1,
              duration: SrsMotion.resolve(context, SrsMotion.press),
              curve: SrsMotion.ease,
              child: widget.builder(context, _hover, _down),
            ),
            if (_focus)
              Positioned(
                left: -2, top: -2, right: -2, bottom: -2,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(widget.radius + 2),
                      border: Border.all(color: c.accent, width: 2),
                    ),
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

/// Filled ink pill. 46dp tall. The ONLY filled button style; at most one per screen.
class SrsPillButton extends StatelessWidget {
  const SrsPillButton({super.key, required this.label, required this.onPressed, this.shortcut});
  final String label;
  final VoidCallback? onPressed;
  final String? shortcut; // e.g. 'Space'; hide on touch-only devices

  @override
  Widget build(BuildContext context) {
    final c = context.srs;
    return SrsPressable(
      onPressed: onPressed,
      semanticLabel: label,
      pressScale: SrsMotion.pressScale,
      builder: (_, __, ___) => Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        decoration: BoxDecoration(color: c.ink, borderRadius: BorderRadius.circular(999)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label, style: SrsText.button(c.ground)),
          if (shortcut != null) ...[const SizedBox(width: 12), SrsKbd(shortcut!, onInk: true)],
        ]),
      ),
    );
  }
}

/// Borderless text action ("Skip"). ink2 -> ink on hover, hairline-soft background on hover.
class SrsTextButton extends StatelessWidget {
  const SrsTextButton({super.key, required this.label, required this.onPressed, this.shortcut});
  final String label;
  final VoidCallback? onPressed;
  final String? shortcut;

  @override
  Widget build(BuildContext context) {
    final c = context.srs;
    return SrsPressable(
      onPressed: onPressed,
      semanticLabel: label,
      radius: 10,
      builder: (_, hover, __) => Container(
        constraints: const BoxConstraints(minHeight: SrsLayout.minTouchTarget),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: hover ? c.hairlineSoft : const Color(0x00000000), borderRadius: BorderRadius.circular(10)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label, style: SrsText.textButton(hover ? c.ink : c.ink2)),
          if (shortcut != null) ...[const SizedBox(width: 10), SrsKbd(shortcut!)],
        ]),
      ),
    );
  }
}

/// Keyboard hint chip. Show only when a hardware keyboard is likely (desktop/web/tablet with keyboard).
class SrsKbd extends StatelessWidget {
  const SrsKbd(this.text, {super.key, this.onInk = false});
  final String text;
  final bool onInk;
  @override
  Widget build(BuildContext context) {
    final c = context.srs;
    final fg = onInk ? c.ground : c.ink2;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: onInk ? c.ground.withValues(alpha: 0.16) : c.hairlineSoft,
        borderRadius: BorderRadius.circular(5),
        border: onInk ? null : Border.all(color: c.hairline, width: 1),
      ),
      child: Text(text, style: SrsText.kbd(fg)),
    );
  }
}

/// Pill segmented control. Selected = ink background, ground text.
class SrsSegmented<T> extends StatelessWidget {
  const SrsSegmented({super.key, required this.options, required this.value, required this.onChanged});
  final Map<T, String> options;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.srs;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: c.hairlineSoft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.hairline, width: 1),
      ),
      child: Wrap(children: [
        for (final e in options.entries)
          SrsPressable(
            onPressed: () => onChanged(e.key),
            semanticLabel: e.value,
            semanticsToggled: e.key == value,
            builder: (_, hover, __) => Container(
              constraints: const BoxConstraints(minWidth: 38),
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
              decoration: BoxDecoration(color: e.key == value ? c.ink : const Color(0x00000000), borderRadius: BorderRadius.circular(999)),
              child: Center(
                widthFactor: 1,
                child: Text(e.value, style: SrsText.seg(e.key == value ? c.ground : (hover ? c.ink : c.ink2))),
              ),
            ),
          ),
      ]),
    );
  }
}

/// 44x26 switch. Off: hairline track, surface knob. On: ink track, ground knob.
class SrsSwitch extends StatelessWidget {
  const SrsSwitch({super.key, required this.value, required this.onChanged, required this.semanticLabel});
  final bool value;
  final ValueChanged<bool> onChanged;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.srs;
    final d = SrsMotion.resolve(context, SrsMotion.toggle);
    return SrsPressable(
      onPressed: () => onChanged(!value),
      semanticLabel: semanticLabel,
      semanticsToggled: value,
      radius: 13,
      builder: (_, __, ___) => AnimatedContainer(
        duration: d,
        curve: SrsMotion.ease,
        width: 44,
        height: 26,
        decoration: BoxDecoration(color: value ? c.ink : c.hairline, borderRadius: BorderRadius.circular(13)),
        child: AnimatedAlign(
          duration: d,
          curve: SrsMotion.ease,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: value ? c.ground : c.surface,
                border: value ? null : Border.all(color: c.hairline, width: 1),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Accent picker: 24dp dots (light-theme or dark-theme value depending on current brightness),
/// selected dot gets a 1.5px ink ring 3.5dp outside it.
class SrsAccentDots extends StatelessWidget {
  const SrsAccentDots({super.key, required this.value, required this.onChanged});
  final SrsAccent value;
  final ValueChanged<SrsAccent> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.srs;
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: c.hairlineSoft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.hairline, width: 1),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        for (final a in SrsAccent.values) ...[
          SrsPressable(
            onPressed: () => onChanged(a),
            semanticLabel: a.name,
            semanticsToggled: a == value,
            builder: (_, __, ___) {
              final color = c.isDark ? kSrsAccents[a]!.dark : kSrsAccents[a]!.light;
              return SizedBox(
                width: 24,
                height: 24,
                child: Stack(clipBehavior: Clip.none, children: [
                  Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(color: color, shape: BoxShape.circle))),
                  if (a == value)
                    Positioned(
                      left: -3.5, top: -3.5, right: -3.5, bottom: -3.5,
                      child: DecoratedBox(decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: c.ink, width: 1.5))),
                    ),
                ]),
              );
            },
          ),
          if (a != SrsAccent.values.last) const SizedBox(width: 8),
        ],
      ]),
    );
  }
}
