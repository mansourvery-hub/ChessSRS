# 05. Flutter implementation

Confirmed from the repo (`pubspec.yaml`, `review_screen.dart`): Flutter **3.47.3**, `chessground: ^10.1.1`,
`dartchess: ^0.13.1`, `flutter_riverpod: ^3.4.2`, `material_ui: ^1.0.1`, `cupertino_ui: ^1.0.0`,
`dynamic_system_colors: ^1.9.0`, `sound_effect: ^0.2.0`, `sqflite: ^2.4.3`, `home_widget: ^0.9.3`,
`flutter_displaymode: ^0.7.0`, plus `fl_chart`, `freezed`, `json_serializable`, `file_picker`, `share_plus`,
Firebase packages. `review_screen.dart` imports `package:material_ui/material_ui.dart` and
`package:material_symbols_icons/symbols.dart`, and uses `GameLayout` from `lib/src/widgets/game_layout.dart`
and `styles.dart` / `lichess_colors.dart` from `lib/src/styles/`. **The author has not read these three files**
(styles.dart, lichess_colors.dart, game_layout.dart) — read them yourself before writing any screen code; the
plan below assumes you will adapt to what's actually in them.

## 1. Architecture: don't fight Riverpod or the domain layer

This package only replaces **presentation**. Everything under `lib/src/domain`, `lib/src/model`,
`lib/src/review/review_controller.dart` (the scheduling logic, not its widget) stays as-is. Concretely:

- Keep `ReviewController` (or whatever Riverpod notifier drives Review) as the source of truth for: current
  position, decision, due count, phase (prompt/correction/note — map your existing states onto
  `04-screens-and-flows.md` §2 if the names differ), scope, practice mode.
- New widgets read that state and render it with the tokens/primitives in this package. Where the current
  code branches on `LichessColors`/`Theme.of(context)` for visuals, branch on `context.srs` instead.
- If the controller's state shape doesn't cleanly expose what a view needs (e.g. "does this position have a
  note", "is a note enabled"), extend the state class — that's a legitimate presentation-adjacent change —
  but do not change scheduling behaviour to do it.

## 2. New package structure

```
lib/src/design/
  tokens.dart            <- flutter/chesssrs_tokens.dart (adapt names to match this repo's conventions)
  hatch.dart
  board_background.dart
  move_arrow.dart
  memory_bar.dart
  notation_line.dart
  review_layout.dart
  primitives.dart
  theme_provider.dart    <- NEW: Riverpod provider(s) for theme mode + accent (see §6)
```

Copy the eight files from `flutter/` in this package into `lib/src/design/`, adjust imports, then run
`dart analyze` and `dart format`. They were written carefully but never compiled (no Dart toolchain was
available while producing this package) — expect small fixes (import paths, nullability, a possible API
mismatch against the exact Flutter 3.47.3 widgets library). Treat analyzer errors as bugs in this package to
fix, not as license to redesign the geometry.

## 3. Fonts

1. Download **Instrument Sans** (400/500/600) and **Newsreader** (400) from Google Fonts (SIL OFL 1.1).
2. Put the `.ttf` files under `assets/fonts/` in the app (see `assets/fonts/README.md` in this package for the
   exact file names expected by `chesssrs_tokens.dart`'s `SrsText`).
3. Register them in the app's `pubspec.yaml` under `flutter: fonts:` with family names `InstrumentSans` and
   `Newsreader` (matching `SrsText.ui` / `SrsText.read`).
4. Do **not** use `google_fonts` (network fetch) — this is a local-first, offline app.
5. Include the OFL licence text in the About/Licences screen and in a `LICENSES` folder if the repo has one.

## 4. Board: chessground integration (read this before writing board code)

The prototype's board (paper squares + hatch + frame + original pieces + curved arrow) is **not** a Lichess
board theme — none of chessground's built-in `ChessboardColorScheme` presets look like this. You are
replacing the visual layer, not picking a theme name. `chessground: ^10.1.1` renders via a `CustomPainter`
driven by `ChessboardController`, and is configured through a `ChessboardSettings` object (piece assets,
colour scheme, border, animation duration, drag settings, draw-shape options) — verify the exact field names
against the version actually in the pub cache (`~/.pub-cache/hosted/pub.dev/chessground-10.1.*/lib/`), since
package APIs move between minor versions and the author could not open that source this session.

**Plan A (preferred): let chessground draw squares as fully transparent, own the background ourselves.**
1. Build `SrsBoardBackground` (this package) as a static layer.
2. Configure chessground's `ChessboardColorScheme` (or equivalent) with `background` set to a *transparent*
   `SolidColorChessboardBackground` (or whatever the installed version calls a flat, paintable background) so
   chessground draws no squares of its own.
3. Stack: `SrsBoardBackground` → `Chessboard`/`ChessboardController`-driven board (pieces + interaction only,
   transparent squares) → `SrsMoveArrow` overlay (`IgnorePointer`) → coordinates.
4. Supply `pieceAssets` pointing at `assets/pieces/{light|dark}/png-512/` (swap the whole `PieceAssets` object
   when the theme brightness changes; use `ChessgroundImages` to precache both sets at startup so switching
   theme doesn't blink).
5. Confirm chessground exposes a `border` setting — if so, you may not need the frame in
   `SrsBoardBackground` at all; use whichever draws a crisper 1.5px line at all board sizes.

**Plan B (if the installed version can't fully transparent-ify squares):** draw `SrsBoardBackground` **on
top** of chessground's own light/dark squares but make chessground's own squares the same flat colours as
`squareLight`/`squareDark` (no hatch), and let `SrsBoardBackground`'s hatch layer sit above it,
`IgnorePointer`-wrapped, painting **only** the hatch strokes (transparent elsewhere) so pointer events still
reach chessground's board underneath.

**Plan C (fallback, more work, only if A and B both fail):** vendor `chessground` (already MIT/GPL-compatible
per its own licence — verify) into a local package or fork pinned to `10.1.1`, and add a
`DiagramChessboardBackground` implementing whatever background interface it exposes, so the hatch and frame
are drawn by chessground's own painter and stay perfectly in sync with square hit-testing.

Do **not** ship a version where the hatch pattern restarts at each square edge (it must look continuous, per
`03-components.md` §3.1) or where the frame is inside the board's hit-test area (it must sit fully outside).

**Arrow:** chessground supports user-drawn shapes (`DrawShapeOptions`, `Arrow`, etc. per its changelog) but
those are for *user* annotations, not a scripted "show the correct move" arrow with a custom curve and
animation. Use `SrsMoveArrow` (this package) as an overlay positioned exactly over the board's `RenderBox`,
independent of chessground's shape system. Confirm it lines up at all board sizes and both orientations by
testing white-at-bottom and black-at-bottom.

**Interaction:** keep chessground's own drag/tap handling (it already does 5px-threshold drag and tap-to-move
per its docs) — do not reimplement piece dragging. Only the visuals (background, pieces, arrow, coordinates)
are replaced.

## 5. Notation line and figurines

`flutter/notation_line.dart` uses `flutter_svg` to render `assets/figurines/{K,Q,R,B,N}.svg` tinted to the
current text colour. This is the **one new dependency** this design needs. If the team prefers zero new
dependencies, alternative: pre-render the five figurines as a tiny `IconData`-compatible font (e.g. with
FlutterIcon or fontello, feeding it the same SVGs) and swap `SrsFigurine`'s implementation to use an `Icon`
instead of `SvgPicture` — the rest of `notation_line.dart` is unaffected either way.

## 6. Theme and accent state

Add Riverpod state for: theme mode (`light` / `dark` / `system`) and accent (`SrsAccent`), persisted the same
way other user preferences are (likely `shared_preferences` or the existing settings store — check
`lib/src/model/settings/`). Expose `SrsColors` via `SrsTheme` (an `InheritedWidget`, in
`chesssrs_tokens.dart`) built from those two providers, placed once near the root, **below** `WidgetsApp`/
`MaterialApp`/whatever the app root is — it does not depend on Material, so it can sit outside or inside a
`MaterialApp` equally well. Do not read `Theme.of(context)` for any colour used by migrated screens.

## 7. Removing Material dependence (incremental, don't boil the ocean)

`review_screen.dart` currently imports `material_ui` and `material_symbols_icons`. Migrate screen by screen
(see §9 phases): replace `AppBar`/`Scaffold`/`Drawer`/`ListTile`/`SwitchListTile`/`AlertDialog`/
`showModalBottomSheet`/chips with the primitives in `flutter/primitives.dart` plus plain `Scaffold`-equivalent
structure from `flutter/review_layout.dart`. It is fine for **not-yet-migrated** screens (Analysis, Explorer,
Editor, per the open decision) to keep using `material_ui`/`cupertino_ui` in the meantime — this is a
presentation migration, not a big-bang rewrite. Do not leave a *migrated* screen with a mix of `Srs*` and
Material widgets past the end of its phase.

`dynamic_system_colors` should stop feeding the app's colour scheme once `SrsTheme` is wired up (a fixed
palette is the point of this identity) — remove its usage in the theme-construction file you found in §0, but
you can leave the dependency in `pubspec.yaml` if something else still uses it; check `AGENTS.md`/decisions
for whether unused deps must be pruned.

## 8. Assets to wire in

```
assets/pieces/light/png-512/{w|b}{K,Q,R,B,N,P}.png   (and png-256 for small contexts)
assets/pieces/dark/png-512/{w|b}{K,Q,R,B,N,P}.png
assets/figurines/{K,Q,R,B,N}.svg
assets/brand/mark.svg          (wordmark glyph, 22x22, currentColor)
assets/brand/icon.svg          (app icon source; also see icon-1024.png)
assets/sounds/{move,wrong,done}.wav
assets/fonts/*.ttf             (see assets/fonts/README.md)
```

Register all of them under `flutter: assets:` (and `fonts:`) in `pubspec.yaml`. Replace the app icon
(`flutter_launcher_icons` config, if present) and the splash (`flutter_native_splash`, currently
`logo-black/white.webp`) with assets derived from `assets/brand/icon.svg` once the owner approves real
artwork — the shipped SVG/PNG here is a placeholder, not final branding.

Remove (after confirming nothing else references them): the bundled Lichess board-thumbnail assets, Lichess
sound sets (`assets/sounds/{standard,futuristic,lisp,nes,piano,sfx}` if that's their actual path — verify),
`LichessIcons`/`SocialIcons`/`LichessPuzzleIcons` icon fonts, and any Lichess piece-set assets not already
removed by earlier trimming work. Check licences before deleting anything you plan to keep in a `third_party`
credits list.

## 9. Suggested phases (one PR each; screenshots required per `00-agent-brief.md`)

0. **Repo doc amendments** (`06-repo-doc-amendments.md`). No UI changes.
1. **Foundation:** add `lib/src/design/`, fonts, piece/figurine/sound assets, `SrsTheme` provider wiring. No
   screen changes yet; add a temporary debug route that renders the tokens/primitives spec (mirrors
   `reference/index.html`'s specimen section) so reviewers can sanity-check colours/type/motion in the real
   app before screens change.
2. **Board:** implement Plan A/B/C from §4 behind a feature flag or on a debug screen first; get it pixel-
   compared against the prototype (all four accents, both themes, both orientations) before touching Review.
3. **Review screen:** replace the app bar, side column, feedback states, Skip/Continue, using
   `review_layout.dart`. Keep the scope drawer and More tab as they are for now (still Lichess-styled) —
   this phase is about the board + side column only.
4. **Scope list + Library sheet:** replace the drawer and the More tab per `03-components.md` §6-7. Remove
   the bottom navigation bar entirely.
5. **Nothing-due, First-launch/Import, Settings:** per `03-components.md` §9-11.
6. **Dialogs, chapters screen, toasts, loading/error states:** per `03-components.md` §12.
7. **Cleanup:** delete unused Lichess assets/icon fonts/screens per the open decisions; prune
   `dynamic_system_colors` usage; update the app icon/splash/name if approved; write the About/Licences
   screen; run the full checklist in `07-acceptance-and-testing.md`.

Each phase's PR description must include: which files in §0 of `00-agent-brief.md` you actually read, any
place this doc's assumptions about the current code turned out to be wrong, and the required screenshots.
