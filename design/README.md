# ChessSRS design package

Everything a coding agent needs to implement the new ChessSRS visual identity ("Diagram") exactly.
Start with the prototype, then read the docs in order.

## 1. Look at it first

Open `reference/index.html` in a browser (Chrome/Edge/Safari/Firefox, current versions). It is a fully working
prototype of the app: drag the knight from b1 to c3, use the toolbar to jump between screens, switch
Desktop / Phone / Resizable, Light / Dark, and the four accents. **The prototype is the visual source of truth.**
If a doc and the prototype disagree, the prototype wins and the doc has a bug: report it.

`reference/prototype-single-file.html` is the same thing in one file. It loads Instrument Sans and Newsreader from
Google Fonts; offline it falls back to system fonts and looks slightly different.

## 2. Read in this order

| # | File | What it answers |
|---|---|---|
| 0 | `docs/00-agent-brief.md` | Mission, constraints, working protocol, definition of done. **Read first.** |
| 1 | `docs/01-identity.md` | The design idea, principles, copy voice, the full string table. |
| 2 | `docs/02-tokens.md` | Every colour, size, type style, duration. (`tokens/tokens.json` is the machine-readable twin.) |
| 3 | `docs/03-components.md` | Exact spec for every component and screen region, with measurements. |
| 4 | `docs/04-screens-and-flows.md` | Screens, the Review state machine, interactions, keyboard, accessibility. |
| 5 | `docs/05-flutter-implementation.md` | How to build it in this Flutter app: architecture, chessground, assets, file-by-file plan, phases. |
| 6 | `docs/06-repo-doc-amendments.md` | Exact edits to `PRODUCT.md`, `design.md`, `decisions.md` etc. **Do these before any UI code.** |
| 7 | `docs/07-acceptance-and-testing.md` | Checklists, screenshot protocol, tests, performance and licence audit. |
| 8 | `docs/08-research-brief-appendix.md` | Background research that led to these decisions (optional). |

## 3. What is in the folders

```
reference/   working HTML/CSS/JS prototype (index.html + styles.css + prototype.js, and a single-file copy)
tokens/      tokens.json (numbers, colours, motion) and tokens.css (the CSS custom properties, verbatim)
assets/
  pieces/    original piece set. light/ and dark/, each with svg/, png-256/, png-512/ (wK.png ... bP.png)
             silhouettes.svg = source paths. Halo is baked in.
  figurines/ single-colour piece silhouettes for inline notation (K Q R B N)
  brand/     mark.svg, icon.svg, icon-1024.png (placeholder wordmark/icon)
  sounds/    move.wav, wrong.wav, done.wav (synthesised placeholders)
  fonts/     README.md: which fonts to download and how to register them
flutter/     reference Dart (tokens, hatch, board background, arrow, memory bar, notation line, primitives, layout)
tools/       export_pieces.py, generate_sounds.py (regenerate assets from source)
```

## 4. Honest status of the contents

- **Prototype, tokens, docs, SVG/PNG/WAV assets:** tested. The prototype was exercised in a headless browser
  in both themes, at desktop, phone and resizable sizes, including a full drag / tap / correction / finish play-through.
- **`flutter/*.dart`:** written carefully but **never compiled** (no Dart toolchain was available). Treat them as exact
  geometry and structure plus a strong starting point. Expect small analyzer fixes.
- **Piece drawings, wordmark, app icon, sounds:** placeholders good enough to ship a first build, not final art.
  Commission or refine them before any public release.
- **Not designed in the prototype:** dialogs, chapters screen, import sheet, loading/error states, analysis/explorer/editor.
  `docs/03-components.md` gives extrapolation rules; get the owner's sign-off on screenshots for those.
- **The app shell was not visible** to the author (`lib/src/styles`, `lib/src/widgets`, `GameLayout`, tab scaffold,
  theme construction). `docs/05` lists what to inspect first and what to do in each case.

## 5. Licences and attribution

- Instrument Sans and Newsreader: SIL Open Font License 1.1 (verify on the download page; bundle the licence files).
- Piece set, figurines, mark: original drawings created for this project (placeholders). Nothing is derived from
  Lichess piece sets.
- The app is a GPL-3.0 fork of Lichess Mobile. Keep all upstream copyright notices, keep `COPYING`/licence files, and
  include an "About and licences" screen that credits Lichess Mobile (GPLv3 requires appropriate legal notices).
  Do not use Lichess's name or logo as branding. This is not legal advice; get it reviewed before publishing.
