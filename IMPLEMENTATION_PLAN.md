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
