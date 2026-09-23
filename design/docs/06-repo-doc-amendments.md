# 06. Repo document amendments

Do this **before** any UI code (`00-agent-brief.md`, phase 0). The repo's own planning documents currently
mandate the Lichess look this project is replacing; if you don't change them, they will pull the design back
toward Lichess the next time an agent (human or AI) consults them. Line numbers will drift — search for the
quoted text rather than trusting line numbers.

## 1. `PRODUCT.md`

Find the section titled (as of the reviewed snapshot) **"Dogmatic Minimalism & Lichess Professional Polish"**,
containing a **"Lichess Design Standards"** subsection that specifies a background of `#161512`, a surface of
`#262421`, and an accent of `#629924`, and language describing the app as inheriting "[Lichess's] professional
board, theme, and interaction patterns."

**Action:** rename the section (e.g. "Visual Identity") and replace the standards block with a short pointer:

```markdown
## Visual identity

ChessSRS ships its own visual identity ("Diagram"), independent of Lichess Mobile's look. The full
specification lives in `design/` (or wherever this design package is placed in the repo):
`design/docs/01-identity.md` (principles and voice), `design/docs/02-tokens.md` (colour, type, motion),
`design/docs/03-components.md` (component specs), `design/docs/04-screens-and-flows.md` (screens and states).
The visual identity is intentionally decoupled from Lichess Mobile's theme — see decision D016.

Lichess Mobile remains the **technical** foundation only (board rendering via chessground, chess rules via
dartchess, the Riverpod/domain architecture). See `CUT_PROPOSALS.md` for what technical foundation is kept.
```

Keep everything else in `PRODUCT.md` that is not about visual styling (the product's actual scope, audience,
non-goals, D001/D008/D015-style product rules) — this amendment is about the *look*, not the product.

## 2. `decisions.md`

Keep existing decisions (including D012, which explains why the fork was chosen — that reasoning about
*technical* foundation is still valid) but **add a new decision**:

```markdown
## D016: Visual identity is independent of Lichess Mobile

**Date:** {date of implementation}
**Status:** accepted

**Context:** D012 chose to fork Lichess Mobile for its technical foundation (chessground, dartchess, the
Riverpod architecture, board rendering). PRODUCT.md's original "Lichess Professional Polish" section also
mandated inheriting Lichess's *visual* theme (colours, typography, component style). Ship review and outside
research concluded that this made ChessSRS visually indistinguishable from a trimmed Lichess Mobile, which
undermines the product's own goal of being recognised as its own product rather than a companion app.

**Decision:** ChessSRS's visual identity ("Diagram") is designed and specified independently of Lichess
Mobile's theme, per the design package referenced from PRODUCT.md. Lichess Mobile remains the technical
foundation only: chess board rendering (chessground), chess rules (dartchess), and the underlying Flutter/
Riverpod architecture are kept; the Material-themed widget layer, Lichess board/piece/sound assets, Lichess
iconography, and Lichess component conventions are replaced.

**Consequences:** `lib/src/styles/` and the Material-based widgets in `lib/src/widgets/` are no longer
preserved as-is (supersedes the "NOT cut" note in `CUT_PROPOSALS.md` for those two paths specifically — see
the amendment there). New screens use the primitives and tokens in the design package instead of
`material_ui`/`cupertino_ui` components. This is a presentation-layer change only; it does not affect
scheduling, persistence, import, or any domain logic.
```

## 3. `CUT_PROPOSALS.md`

Find the line(s) stating that `styles/` and `widgets/` are explicitly **not** cut (framed as "preserve the
Lichess technical foundation"). **Do not delete these directories** — most of `lib/src/widgets/` (layout
scaffolding, non-visual logic) and parts of `lib/src/styles/` may still be structurally useful — but add a
clarifying note so "not cut" is not read as "not restyled":

```markdown
> **Amended by D016:** "not cut" here means these directories are not deleted wholesale; it does not mean
> their *visual* contents (Lichess colours, Material-styled components, Lichess-specific widgets) are frozen.
> The visual identity in `design/docs/` supersedes the Lichess-styled parts of `styles/` and `widgets/`.
> Structural/non-visual code in these directories (layout math, platform adapters unrelated to look) may still
> be kept and reused where it doesn't conflict with the new design.
```

## 4. `AGENTS.md`

Find the reference to following "Lichess Mobile conventions (CLAUDE.md)" for UI/visual work specifically (as
opposed to general engineering conventions like commit style, testing, or architecture, which can still point
to the inherited `CLAUDE.md` where they don't concern visuals). Add:

```markdown
## Visual work

For anything touching layout, colour, typography, iconography, motion, or component choice, follow
`design/docs/` (see `design/README.md`), not Lichess Mobile's visual conventions in the inherited `CLAUDE.md`.
Lichess Mobile conventions still apply to non-visual engineering practices (testing, architecture, commit
hygiene) inherited via `CLAUDE.md`.

Screenshot evidence is required for visual PRs (this was already the rule; it now also applies against the
design package): capture the affected screens at phone, tablet and desktop widths, light and dark, and compare
them against `design/reference/index.html` shown at the same sizes/themes.
```

## 5. Where to put this package in the repo

Recommended: copy this entire folder to `design/` at the repo root (so paths above — `design/docs/...`,
`design/reference/...` — resolve). If the team prefers a different location (e.g. `docs/design/`), update the
pointers above to match, consistently, in the same PR.

## 6. Verify before merging

Search the repo for other places that quote the old palette (`#161512`, `#262421`, `#629924`) or say "Lichess
Professional Polish" / "Lichess Design Standards" (README, onboarding docs, code comments) and update or
remove them so nothing contradicts D016.
