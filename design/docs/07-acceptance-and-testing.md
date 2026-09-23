# 07. Acceptance, testing, and audits

## 1. Lichess-fingerprint removal checklist

Go through each row; every one must be checked before calling the redesign complete (see the fingerprint audit
in `08-research-brief-appendix.md` §3 for why each row matters).

- [ ] Board renders the print-diagram background (hatched dark squares, ink frame) at every size tested, not
      any `ChessboardColorScheme` preset.
- [ ] All pieces are the original set (`assets/pieces/`); no `cburnett`, `merida`, or any bundled Lichess piece
      set remains reachable from Settings or anywhere else.
- [ ] All move/capture/UI sounds are the new set (or better, commissioned replacements); none of
      `standard/futuristic/lisp/nes/piano/sfx` (or whatever the actual bundled Lichess sound folders are named
      — verify) remain selectable.
- [ ] No `#161512` / `#262421` / `#629924` (or any other Lichess palette value) appears anywhere in code or
      assets.
- [ ] No stock `material_ui`/Material components remain on the Review, Nothing-due, Scope, Library,
      First-launch, or Settings screens (spot-check with `flutter analyze` for `Colors.*` / `Theme.of(` in
      those files, and visually).
- [ ] `LichessIcons`, `SocialIcons`, `LichessPuzzleIcons` fonts removed from `pubspec.yaml` and unreferenced.
- [ ] `dynamic_system_colors` no longer feeds the app's theme (fixed palette per `SrsTheme`).
- [ ] App name, bundle id, splash image, and app icon no longer reference "lichess" (verify the iOS widget
      extension target name and any `org.lichess.*` identifiers found during `00-agent-brief.md` step 3).
- [ ] Bottom navigation bar removed; no "More" tab with a `lichess.org` logo remains.
- [ ] Kept Lichess-styled screens (Analysis/Explorer/Editor), if any remain per the open decision, are not
      reachable from the primary Review flow without deliberate navigation, and are flagged for a follow-up
      restyle.

## 2. Visual QA matrix

For the Review, Nothing-due, Scope, Library, First-launch, and Settings screens, capture and compare against
`reference/index.html`:

| Dimension | Values |
|---|---|
| Size | phone (~390x844), tablet portrait (~820x1180), desktop (1280x800) |
| Theme | light, dark |
| Accent | at minimum ultramarine (default); spot-check one more |
| Density/scale | default text scale, and one large-text-scale pass on phone |

For Review specifically, capture all of: prompt, correction (wrong move played), note (correct move with
commentary), quiet-to-next transition (before/after), and the hand-off into Nothing-due. Confirm the board's
bounding box is pixel-identical across prompt/correction/note at a fixed window size (this is the "no layout
shift" requirement — a script that measures the board `RenderBox` before and after each transition is a good
regression test).

## 3. The "nobody suspects Lichess" test (owner runs this, not the agent)

1. **Five-second test.** Show the Review screen for five seconds to ~10 chess players (mix of Lichess users
   and non-users). Ask "what does this remind you of?" Pass: Lichess named by at most 1 of 10, and by none of
   the non-Lichess users.
2. **Silhouette test.** Blur/desaturate screenshots of the new Review screen, Lichess, and Chess.com; shuffle;
   ask testers to identify which is which. Pass: testers distinguish yours from both at better than chance.
3. Run the fingerprint checklist (§1) as a pass/fail alongside these.

This test needs real users and is out of scope for the implementing agent to run alone, but the agent should
make sure screenshots are ready for the owner to use.

## 4. Automated tests to add or update

- **Golden tests** (`flutter test --update-goldens` workflow) for: `SrsBoardBackground` (light + dark,
  including the hatch), `SrsMoveArrow` (a couple of representative from/to pairs, both orientations),
  `SrsMemoryBar` (a few ratios, including all-zero and all-one-state edge cases), `SrsNotationLine` (a line
  with and without a filled answer, with a figurine move), and the Review side column at both narrow and wide
  widths.
- **Widget tests**: Skip/Continue visibility per state (`04-screens-and-flows.md` §2-3), keyboard shortcuts
  (Space/Enter/S/P/Esc), sheet open/close and focus return, switch/segmented/accent-dot semantics
  (`Semantics` toggled/selected values).
- **Regression test** for board-size stability: render prompt → correction → note → prompt in a fixed-size
  test harness and assert the board's `Size` is identical at each step.
- Note (from `AGENTS.md`, already in force): passing automated tests is not sufficient evidence for visual
  correctness — screenshots are still required per `00-agent-brief.md`.

## 5. Performance budget

- Target frame time within budget (≤16.7 ms at 60 Hz, ≤8.3 ms at 120 Hz) in **Profile mode** on a mid-range
  Android device and an older supported iPhone, measured with Flutter DevTools' performance view during: a
  drag-move, a tap-move, the correction-arrow animation, and rapid scope-sheet scrolling.
- No `saveLayer`, backdrop blur, or large soft shadows anywhere in migrated screens (the sheet shadow in
  `02-tokens.md` §4 is the one allowed shadow, and it is static, not animated).
- `SrsBoardBackground` must be wrapped in `RepaintBoundary` and must not repaint during piece drag or the
  arrow animation (verify with the "repaint rainbow" debug overlay).
- Cold start to a usable Review screen should not regress versus the pre-redesign baseline; measure both.
- Request high refresh rate on capable Android devices (the app already depends on `flutter_displaymode`;
  confirm it's actually invoked).

## 6. Licence and attribution audit

- Confirm Instrument Sans and Newsreader are SIL OFL 1.1 at the time of download (licence terms can change
  between releases) and bundle their licence files.
- Confirm the piece set, figurines, mark, and icon shipped in this package (or their commissioned
  replacements) are original work with no derivation from any Lichess piece set; keep a record of authorship
  for anything commissioned.
- Confirm the placeholder sounds (or their replacements) are original.
- Add or update an **About and licences** screen (`03-components.md` §12) crediting Lichess Mobile as the
  technical foundation (GPL-3.0) with a link to its source, and listing every third-party asset licence. This
  satisfies GPLv3 §5(d)'s "appropriate legal notices" requirement for interactive programs — confirm with
  whoever handles the project's legal review; this package is not legal advice.
- Confirm no Lichess name/logo is used as ChessSRS branding anywhere (app store listing, splash, about
  screen, icon).
