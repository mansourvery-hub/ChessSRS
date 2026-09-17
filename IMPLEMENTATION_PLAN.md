# Implementation Plan & Phase Status

> Reset plan (post Lichess-Mobile foundation decision). The previous task
> graph (T1–T17, standalone implementation) is archived at git tag
> `legacy/pre-reset` and is closed.

## Phase strategy

```text
Phase 0 — Repository archaeology          (documentation/reset — no product code)
Phase 1 — Lichess Mobile foundation        (fork runs, identity, staged cuts)
Phase 2 — Minimal product vertical slice   (study → position → review → answer
                                             → feedback → local persistence)
Phase 3 — Beta                            (owner uses it; cluster feedback)
Phase 4 — Listudy integration             (training/study-tree behavior)
Phase 5 — chessrs integration              (SRS/review queue behavior)
Phase 6 — Refinement                      (polish, perf, remaining cuts)
```

Development is beta-first: the owner is the beta tester. Nothing gold-plates
before the core review loop is in the owner's hands.

---

## Phase 0 — Repository archaeology (current)

- [x] Inspect old repository (docs + lib + tests); classify documentation
- [x] Inspect Lichess Mobile architecture (model/view/network/db, CLAUDE.md,
      study subsystem, chessground/dartchess)
- [x] Inspect Listudy (study.js training loop, tree_utils, chapter/FEN model)
- [x] Inspect chessrs (Move entity, SpacedRepetitionService, practice queue UX)
- [x] Legacy checkpoint: commit WIP, tag `legacy/pre-reset`, branch `legacy`
- [x] `CUT_PROPOSALS.md` (Lichess trim map + owner sign-off list)
- [x] `docs/INTEGRATION_MAP.md` (Listudy/chessrs extraction + license rules)
- [x] Rewrite `ARCHITECTURE.md`, `AGENTS.md`, `IMPLEMENTATION_PLAN.md`
- [x] Handoff report delivered (A–I)

## Phase 1 — Lichess Mobile foundation

- [x] **F1: Hard reset of working tree** — remove old `lib/`, `test/`,
      `pubspec.*`, platform dirs, `start.sh`; copy Lichess Mobile source
      (LICENSE + COPYING.md preserved). No feature removal.
- [x] **F2: Tooling baseline** — FVM pinned to Flutter 3.47.3 (upstream
      requirement), `pub get`, `build_runner build` (197 outputs), `./verify`
      adapted. Gate: verify green.
- [x] **F3: Build & launch** — Linux desktop launch had 11 startup errors
      (Firebase/libsecret/quick_actions/home_widget/sound guards missing on
      desktop targets); fixed fail-soft. Final: **zero startup errors**,
      analyze 0 issues, tests 1570/1570, home tab renders with board +
      navigation. Evidence: `docs/phase1_runtime_evidence.png` (2026-09-14).
- [x] **F4: App identity** — renamed to **ChessSRS**: Dart package
      `chess_srs` (566 files), Linux binary/GTK id `org.chesssrs.chess_srs`,
      Android namespace/applicationId `org.chesssrs.app` (Kotlin moved),
      iOS bundle ids/display name/app groups, user agent, README with GPL
      fork attribution. Gate: analyze 0, tests 1570/1570, Linux launch zero
      startup errors. Evidence: `docs/phase1_f4_identity_evidence.png`.
- [x] **F-github: Repository setup** — GitHub fork of `lichess-org/mobile`
      named `ChessSRS`; `main` grafted onto both the old
      `chess-repertoire-srs` history (first-parent) and lichess upstream
      (merge), so the repo descends from both; old repo pushed fast-forward;
      `legacy` branch + `legacy/pre-reset` tag pushed.
- [x] **F5+: Staged cuts** — executed `CUT_PROPOSALS.md` execution order
      (one subsystem per commit; verify + launch after each). Owner has
      reviewed and approved/rejected each cut — see `CUT_PROPOSALS.md`
      §Owner decisions for the full record. Final ordered status:
      1. `[x]` C9  — Learn tab + coordinate training  *(done: f74627873)*
      2. `[x]` UI  — Lichess branding (donate, about, LichessMessage, welcome card) *(done: 1af79eab3 & 72c85e67f)*
      3. `[x]` C11 — Over-the-board game and standalone clock tool *(done: 4d1c4b211 & 1b7e18a03)*
      4. `[x]` C7  — Watch tab (TV / tournaments / broadcasts) *(done: dd996ee74)*
      5. `[x]` C6  — Puzzles tab *(done: fb4847be2)*
      6. `[x]` C10 — Blog / recap / announce (home carousels + model) *(done: 156d760fa)*
      7. `[x]` C4  — Online play: lobby / seek / challenges *(done: c2094c070)*
      8. `[x]` C5  — Server game lifecycle + correspondence *(done: bc7b4dcc4)*
      9. `[x]` C8  — Social cleanup: More tab entries, Home friends carousel, and message service poller *(done)*
      10. `[K]` C17 — WebSocket *(KEPT by owner decision for study sync & cloud eval)*
      11. `[K]` C18 — HTTP network & core repositories *(KEPT for auth, study import, explorer, tablebase)*
      12. `[x]` Tab reduction → Clean 2-tab shell: Review (primary) + More/Settings *(done)*
      Grey/undecided (untouched): C1, C2, C12, C13, C15.
      Kept by owner decision: C3, C14, C16, C17, C18.
- [x] **F-end: Foundation stable** — a clean, coherent, Lichess-derived
      application shell with Home and More tabs. 0 analyzer warnings,
      1,084 passing tests, desktop runtime verified. Ready for Phase 2.

## Phase 2 — Minimal product vertical slice

- [x] **V1: Domain module** — pure-Dart domain (Study, Chapter, repertoire
      tree, RepertoireDecision, ReviewState, Scheduler + SimpleScheduler,
      Clock) with unit tests. Contract-first; no UI. *(done: 9f879c5e0)*
- [x] **V2: Import pipeline** — PGN file → dartchess `PgnParser` →
      normalized Study/Chapter/tree (RAVs preserved, FEN headers honored);
      structured error reporting. Tests: legacy contract references
      translated (variation preservation, multi-chapter). *(done: f65aa3184)*
- [x] **V3: Local persistence** — sqflite store for studies/decisions/review
      states; incremental writes. Tests: durability across restart. *(done: 2c44df649)*
- [x] **V4: Review session engine** — due selection, move validation against
      repertoire, auto-traversal of non-due material, opponent auto-reply,
      feedback state machine. Deterministic Clock tests. *(done: 1aeb1bbf2)*
- [x] **V5: Review scene UI** — board-dominant Review screen on chessground,
      oriented to repertoire side, quiet correct/incorrect feedback,
      due-count indicator, scope drawer (all/one study). First launch with
      no studies → import action. *(done: b940ffbf8)*
- [x] **V6: Vertical slice gate** — full loop proven at runtime on device:
      import real PGN → review → correct/incorrect → state persisted across
      restart. Runtime validation (Linux desktop build & launch) + automated
      end-to-end vertical slice gate test. **Beta-ready.** *(done: 00160c1c5)*

## Phase 3 — Beta & Owner Feedback Refinements

- [x] Deliver initial vertical slice build to owner for daily use. *(done: 2026-09-16)*
- [x] Clustered beta feedback audit 1: move pacing, unblocking reguess on error, quiet positive feedback, study explore mode, Home tab removal. *(done: b313f61ce & 29c3db19e)*
- [x] **B1: Immediate Import Transition & Move Comment Spoiler Prevention**
      1. Immediate scope transition: upon successful PGN import, automatically switch active `ReviewScope` to the newly imported study.
      2. Move comments strictly hidden during active recall prompt to prevent move spoilers.
      3. Move comments revealed post-guess (on success or lapse) with multiline wrapped text. *(done: 763a50181)*
- [x] **B2: Active Review Pool Toggle (Deck Muting / Study Suspension)**
      1. Persistence update: `isActive` boolean (default `true`) on `Study` / `srs_study`.
      2. `ReviewScope.all()` and total due count query only active studies.
      3. Quick toggle switch next to each study in `ReviewScopeDrawer`.
      4. Inactive studies remain fully accessible for individual study review, explore mode, and cram mode. *(done: 4ee5a030f)*
- [x] **B3: Pre-Match Rehearsal / Cram Mode (Custom Review)**
      1. `ReviewMode` parameter on session (`srs` vs `practice`).
      2. In `practice` mode, tests moves on the board without updating `ReviewState` or logging `ReviewEvent` (zero SRS writes/interval corruption).
      3. Entry points: "Rehearse Moves" on "All Caught Up" screen and in study drawer options. *(done: 4d9bd9762)*
- [x] **B4: Automatic Opening Classification & Cross-Study Opening Hubs**
      1. Automatic opening name & ECO tag derivation from PGN headers or position FEN.
      2. `ReviewScope.opening(String name)` virtual scope aggregating decisions across studies.
      3. Opening Hub section in `ReviewScopeDrawer`. *(done: eebb20632)*
- [x] **B5: Smooth Study Management & Native Study Analysis (Option A)**
      1. Eliminate full-screen refresh and UI wipeout on study suspension and rename via optimistic in-memory updates.
      2. Batched due-count computation (`getDueSummary` and `getChapterOpenings`) preventing recursive JSON tree parsing loops during count queries.
      3. Native study analysis: single-chapter studies route directly to `AnalysisScreen`, multi-chapter studies open `StudyChaptersScreen`.
      4. `AnalysisScreen` displays study name and chapter name from PGN headers. *(done: 2026-09-17)*
- [x] **B6: Opponent Pre-Move Animation on Line Transitions & Settings Toggle**
      1. Domain: `parentFen` and `incomingMove` tracked on `ReviewPrompt` via parent node indexing in `ReviewSession`.
      2. Preferences: `animateOpponentPreMove` toggle in `StudyPrefs` and `SettingsScreen`.
      3. UX: When transitioning to a new variation, at session start, or on skip, the board loads the parent position and smoothly animates the opponent's incoming move with sound and square highlights before prompting the user's recall. *(done: 2026-09-17)*

## Phase 4 — Listudy integration (isolated modules)

- [x] **L1: Due-Aware & Weighted-Random Opponent Reply Selection (Listudy Semantics)**
      1. Repertoire branching: opponent variation selection inspects subtrees for due decisions.
      2. Branches containing due cards are prioritized so drills dynamically guide the player to due material rather than always playing `.first`.
      3. Multiple due branches are selected using weighted randomness proportional to due move density, preventing repetition across sessions.
      4. Fallback in Practice Mode weights by subtree size so all variations get proportionate practice.
      5. Full deterministic replay in tests via injectable `Random`. Documented in `docs/review.md`. *(done: 2026-09-17)*
- [x] **L2: PGN Visual Shapes (`[%cal ...]` & `[%csl ...]`) Post-Guess & Settings Toggle**
      1. Zero-spoiler invariant: commentary shapes (arrows and circle highlights) are strictly hidden during active recall.
      2. Post-guess reveal: on correct answer or lapse, PGN shapes from study comments are rendered directly onto the Chessground board.
      3. Clean text: `PgnComment.fromPgn` strips raw `[%cal ...]` and `[%csl ...]` tags from displayed text descriptions.
      4. Distraction-free toggle: "Show board arrows & shapes" switch added in `SettingsScreen` backed by `StudyPrefs.showAnnotations`. *(done: 2026-09-17)*

Per `docs/INTEGRATION_MAP.md`: remaining training-loop semantics (sibling reset on
error, weighted-random opponent replies), chapter/FEN behaviors, tree caching
by PGN hash. Optional where flagged (hints, arrows, comments) — only with
beta-feedback justification.

## Phase 5 — chessrs integration (isolated modules)

Per `docs/INTEGRATION_MAP.md`: ease/scaling scheduler as second `Scheduler`
implementation (user-tunable), queue prefetch behavior, opening grouping
cross-study. FSRS remains a later option — never a redesign.

## Phase 6 — Refinement

Workflow polish, information architecture, performance, onboarding/import
improvements, remaining Lichess code removal (per CUT_PROPOSALS §2), and only
then differentiation features justified by specs or beta feedback.

---

## Recording rule

Every completed task records: what shipped, verification evidence (verify +
runtime), and date. Boundary changes update ARCHITECTURE.md/QUALITY.md in the
same commit.
