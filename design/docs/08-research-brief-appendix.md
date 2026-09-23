# 08. Research brief appendix

This document records the reasoning that produced the design in this package, for anyone who wants the "why"
behind a "what" in `01`-`07`. It is optional reading for implementation; nothing here overrides those docs.

## Where this came from

The design was developed in two passes against a `repomix` export of the ChessSRS repository plus four
screenshots of the running app (Windows desktop build, debug mode): the scope drawer, the "More" tab (showing
a `lichess.org` header and Import/Analysis/Explorer/Editor/Settings rows), and the Review screen mid-lesson
with a "Move Explanation" card. The first pass produced a written research brief (fingerprint audit, learning-
science constraints, three candidate directions, feasibility notes, a validation plan); the second pass built
`reference/index.html` as a working prototype and, on request, added the four-accent system; this package is
the hand-off of that prototype into implementation-ready docs and code.

## Key findings that shaped the decisions in `01`-`04`

1. **"Lichess-ness" lives in five layers**, not mainly in colour: board/pieces, sound, the Material widget
   layer, the screen skeleton (menus, chips, cards), and the repo's own documents, which explicitly mandated
   Lichess's palette. A palette swap alone would not have cleared the "nobody suspects a fork" bar — see
   `06-repo-doc-amendments.md` for why the documents had to change too.
2. **The pre-redesign Review screen already violated the repo's own `design.md`** ("do not surround the board
   with a dense control panel"): roughly five persistent controls plus a due-count chip around the board, and
   three feedback-card variants of different heights that risked resizing the board between states. This
   directly motivated the "chrome budget" and "fixed regions" principles in `01-identity.md` and
   `03-components.md`.
3. **Piece licensing is a real constraint, not just a look.** Many popular Lichess piece sets are
   CC BY-NC-SA 4.0; a small number are MIT or CC0. Shipping any recognisable Lichess set is both a
   fingerprint problem and, for NC-licensed sets, a poor fit if the product is ever monetised. This is why the
   package ships an original piece set rather than reusing or lightly editing a Lichess set.
4. **Learning-science constraints, not just aesthetics, shaped several rules:**
   - Corrective feedback with an immediate re-test is well supported for retention; feedback *timing*
     (immediate vs delayed) is genuinely disputed in the literature, which is why the design does not build
     around a timing claim — it keeps feedback clear and non-blocking rather than instant-vs-delayed.
   - Chess expertise research (chunking) suggests board fidelity — consistent geometry, scale, and
     orientation, distinguishable piece silhouettes — is a memory variable, not decoration, which is why the
     hatch/board geometry is specified precisely and why the piece set prioritises clear silhouettes.
   - The product's own decision that thinking time is not graded (no timers/urgency) is treated as a hard
     motion constraint (`02-tokens.md` §5, `01-identity.md` principle 3).
   - Correct/incorrect is deliberately never encoded as green/red, both for colour-blind accessibility and to
     avoid the gamified "right answer ding" feel the product's non-goals exclude.
5. **A three-way positioning judgement** (a "contemplative instrument" aesthetic vs. a utilitarian dark
   Lichess-style tool vs. a playful Chess.com/Duolingo-style tool) favoured the quieter, print-diagram
   direction implemented here, on the reasoning that it best fits a focused, retention-first tool for
   tournament/club players — this is a judgement call, not a proven result; the acceptance tests in
   `07-acceptance-and-testing.md` §3 are how to check it against real users.

## What was explicitly out of scope for the research

- A visual audit of competitor apps' actual screenshots (Chessable, Chessbook, Listudy, etc.) — only their
  general market positioning was researched, not their pixel-level design.
- Reading `lib/src/styles/`, `lib/src/widgets/`, the app's theme-construction file, or the tab scaffold — the
  repomix export did not include them and the author's repository browser could not open GitHub's directory
  pages. `00-agent-brief.md` §0 lists this as the first thing an implementing agent should do.
- Compiling or testing any of the Flutter reference code (no Dart toolchain was available) — see
  `05-flutter-implementation.md` and the honesty note in the top-level `README.md`.
- Any user testing. The five-second and silhouette tests in `07-acceptance-and-testing.md` §3 have not been
  run; they are proposed acceptance criteria, not reported results.

## Numbers that are proposals, not measurements

Every duration, size, and threshold in `02-tokens.md` was authored to match the working prototype (verified by
rendering it), which makes them accurate *specifications* of that prototype. They are not, however, the
result of user testing or performance profiling on a real device — treat the performance targets in
`07-acceptance-and-testing.md` §5 and the memory-state thresholds in `04-screens-and-flows.md` §7 as starting
points to validate, not settled facts.
