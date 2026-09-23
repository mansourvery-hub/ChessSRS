// Bridge between SrsColors and Material ThemeData.
// The app still uses MaterialApp, so we generate a ThemeData that is
// visually consistent with the design tokens. This lets un-migrated
// screens (analysis, editor) look reasonable while migrated screens
// read tokens from SrsTheme.of(context) directly.
import 'package:chess_srs/src/design/tokens.dart';
import 'package:material_ui/material_ui.dart';

ThemeData srsThemeData(SrsColors c) {
  final brightness = c.brightness;
  final cs = ColorScheme(
    brightness: brightness,
    primary: c.accent,
    onPrimary: c.ground,
    secondary: c.accent,
    onSecondary: c.ground,
    error: const Color(0xFFB3261E),
    onError: const Color(0xFFFFFFFF),
    surface: c.surface,
    onSurface: c.ink,
    surfaceContainerLowest: c.ground,
    surfaceContainerLow: c.ground,
    surfaceContainer: c.ground,
    surfaceContainerHigh: c.surface,
    surfaceContainerHighest: c.surface,
    surfaceDim: c.page,
    onSurfaceVariant: c.ink2,
    outline: c.hairline,
    outlineVariant: c.hairlineSoft,
    inverseSurface: c.ink,
    onInverseSurface: c.ground,
    shadow: c.scrim,
    scrim: c.scrim,
  );

  return ThemeData(
    brightness: brightness,
    colorScheme: cs,
    scaffoldBackgroundColor: c.ground,
    fontFamily: SrsText.ui,
    splashFactory: NoSplash.splashFactory,
    appBarTheme: AppBarTheme(
      backgroundColor: c.ground,
      foregroundColor: c.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    bottomAppBarTheme: BottomAppBarThemeData(
      color: c.ground,
      elevation: 0,
    ),
    dividerTheme: DividerThemeData(
      color: c.hairline,
      thickness: 1,
      space: 1,
    ),
    iconTheme: IconThemeData(color: c.ink2),
    listTileTheme: ListTileThemeData(
      textColor: c.ink,
      iconColor: c.ink2,
    ),
    cardTheme: CardThemeData(
      color: c.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: c.hairline),
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
    ),
    sliderTheme: const SliderThemeData(
      // ignore: deprecated_member_use
      year2023: false,
    ),
  );
}
