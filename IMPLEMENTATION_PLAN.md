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

- [ ] **F1: Hard reset of working tree** — remove old `lib/`, `test/`,
      `pubspec.*`, platform dirs, `start.sh`; copy Lichess Mobile source
      (LICENSE + COPYING.md preserved). **No feature removal yet.**
- [ ] **F2: Tooling baseline** — `fvm flutter pub get`, `build_runner build`,
      recreate `./verify` (analyze + test), `.gitignore` adapted.
      Gate: verify green.
- [ ] **F3: Build & launch** — `fvm flutter run -d linux` launches; manual
      smoke run; record runtime evidence. Gate: runtime pass.
- [ ] **F4: App identity** — rename app (pubspec name, display name, Android
      namespace/ios bundle later), launcher icons, remove upstream-only
      tooling where trivial. Gate: verify + launch.
- [ ] **F5+: Staged cuts** — execute `CUT_PROPOSALS.md` in the order of its
      §6 (one subsystem per commit; verify + launch after each):
      Firebase/notifications → auth → online play/game → puzzles/learn/watch/
      social/blog → engine/explorer/analysis/board-editor → socket/HTTP →
      tab reduction (Review primary) → final rename polish.
- [ ] **F-end: Foundation stable** — a clean, coherent, Lichess-derived
      offline application shell with our tabs. Owner reviews cut result.

## Phase 2 — Minimal product vertical slice

- [ ] **V1: Domain module** — pure-Dart domain (Study, Chapter, repertoire
      tree, RepertoireDecision, ReviewState, Scheduler + SimpleScheduler,
      Clock) with unit tests. Contract-first; no UI.
- [ ] **V2: Import pipeline** — PGN file → dartchess `PgnParser` →
      normalized Study/Chapter/tree (RAVs preserved, FEN headers honored);
      structured error reporting. Tests: legacy contract references
      translated (variation preservation, multi-chapter).
- [ ] **V3: Local persistence** — sqflite store for studies/decisions/review
      states; incremental writes. Tests: durability across restart.
- [ ] **V4: Review session engine** — due selection, move validation against
      repertoire, auto-traversal of non-due material, opponent auto-reply,
      feedback state machine. Deterministic Clock tests.
- [ ] **V5: Review scene UI** — board-dominant Review screen on chessground,
      oriented to repertoire side, quiet correct/incorrect feedback,
      due-count indicator, scope drawer (all/one study). First launch with
      no studies → import action.
- [ ] **V6: Vertical slice gate** — full loop proven at runtime on device:
      import real PGN → review → correct/incorrect → state persisted across
      restart. Runtime validation + screenshots. **Beta-ready.**

## Phase 3 — Beta

- [ ] Deliver build to owner for daily use.
- [ ] Collect UX problems, missing workflows, visual issues, performance
      problems (cluster feedback before building).
- [ ] Fix blocking issues only.

## Phase 4 — Listudy integration (isolated modules)

Per `docs/INTEGRATION_MAP.md`: training-loop semantics (sibling reset on
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
