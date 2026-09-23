# Agent Operating Guidelines & Authority Hierarchy

## 0. Foundation context (read first)

This application is a **fork of Lichess Mobile** (GPL-3.0) rebuilt as a
**local-first chess repertoire + spaced-repetition trainer**. The previous
standalone implementation is archived at git tag `legacy/pre-reset` — it is
reference material only. Never resurrect old `lib/` code because class names
look familiar; the domain *contracts* are specified in the Markdown documents
and must be reimplemented cleanly inside the Lichess Mobile architecture.

Before doing anything in the codebase, read:
1. `ARCHITECTURE.md` (layer boundaries, licensing constraints)
2. `CUT_PROPOSALS.md` (what Lichess functionality is removed/kept, and status)
3. `docs/INTEGRATION_MAP.md` (how Listudy/chessrs concepts are integrated)
4. `CLAUDE.md` in the repo root — the Lichess Mobile contributor guide
   (Riverpod 3.x patterns, Freezed, code generation, formatting, testing
   patterns). It remains authoritative for the foundation's conventions.

## 1. The Authority Hierarchy

```text
PRODUCT.md
    ↓ (product vision, user journeys, functional & UX requirements)
MVP.md
    ↓ (current active scope, included/excluded capabilities)
ARCHITECTURE.md
    ↓ (Lichess foundation, layer boundaries, licensing)
QUALITY.md
    ↓ (non-negotiable engineering, domain, performance invariants)
TEST_STRATEGY.md
    ↓ (how invariants are mechanically proven)
IMPLEMENTATION_PLAN.md
    ↓ (phases, tasks, execution status)
AGENTS.md  ← you are here
```

**Rule**: Code implements specifications. Code is not the specification. If
requirements or architectural boundaries change, update the authoritative
specification documents accordingly.

## 2. Development phases (beta-first)

The strategy is: **foundation → minimal vertical slice → beta → feedback →
refinement → additional modules**. See `IMPLEMENTATION_PLAN.md` for the live
phase status. The owner is the beta tester. Do not gold-plate before the core
review loop is in the owner's hands.

Do NOT start Listudy/chessrs integration work until the foundation is stable
and the vertical slice exists (unless the task explicitly says otherwise).

## 3. The Development Loop

Every engineering task must follow:

```text
1. SELECT READY TASK from IMPLEMENTATION_PLAN.md (dependencies complete).
2. READ THE SPEC: PRODUCT/MVP/ARCHITECTURE/QUALITY sections that apply.
3. DEFINE A SMALL CONTRACT: testable, incremental brick.
4. WRITE TESTS with the contract (dart test, widget test, or integration
   test as appropriate).
5. IMPLEMENT minimally, following Lichess Mobile conventions (CLAUDE.md).
6. TARGETED VERIFICATION: run the specific test file.
7. FULL GATE: ./verify  (flutter analyze + flutter test) — zero warnings.
8. RUNTIME VALIDATION (see §4) for anything user-visible.
9. FIX ROOT CAUSES; add permanent regression tests.
10. UPDATE IMPLEMENTATION_PLAN.md / spec docs if boundaries changed.
11. ATOMIC COMMIT matching repository conventions.
```

### Lichess Mobile conventions that always apply

- Riverpod 3.x (`.value`, not `valueOrNull`; no `ProviderListenable` type
  annotations). Prefer HTTP-layer mocking over provider overrides in tests.
- Freezed + fast_immutable_collections for data classes; generated files are
  never committed; run `dart run build_runner build` after model changes.
- `flutter analyze` on every edited file (including tests) — zero warnings.
- `dart format` every edited file (page width 100).
- Package imports, single quotes, strict-casts/inference/raw-types.
- Translations: hardcoded English first; l10n pipeline only after stability.

### Visual work

For anything touching layout, colour, typography, iconography, motion, or
component choice, follow `design/docs/` (see `design/README.md`), not Lichess
Mobile's visual conventions in the inherited `CLAUDE.md`. Lichess Mobile
conventions still apply to non-visual engineering practices (testing,
architecture, commit hygiene) inherited via `CLAUDE.md`.

Screenshot evidence is required for visual PRs (this was already the rule; it
now also applies against the design package): capture the affected screens at
phone, tablet and desktop widths, light and dark, and compare them against
`design/reference/index.html` shown at the same sizes/themes.

## 4. Runtime validation is mandatory

Past sessions produced green `./verify` runs while the real app had runtime
errors or looked nothing like the intended UI. Therefore, for every
user-visible milestone:

1. `./verify` passes (analyze + tests).
2. **Launch the real application** (Linux desktop or attached device) and
   manually exercise the affected feature.
3. Visually inspect the UI. For UI work, screenshot/runtime inspection is
   required — "tests pass" is not evidence of "visual pass".
4. Only then declare the milestone complete and record it in
   `IMPLEMENTATION_PLAN.md`.

Commands (FVM-pinned toolchain):

```bash
fvm flutter pub get
dart run build_runner build      # after model/codegen changes
fvm flutter analyze
fvm flutter test
fvm flutter run -d linux          # runtime validation
```

`./verify` is the adapted quality gate; keep it green on every commit.

## 5. Quality gates and invariants

- `QUALITY.md` invariants are binding: pure domain layer, single chess
  representation (dartchess), local-first critical path, variation
  preservation, position identity, incremental persistence, deterministic
  clocks.
- `TEST_STRATEGY.md` defines the enforcement matrix; update it when the
  enforcement mechanism changes (not just when tests move).
- Old legacy tests (tag `legacy/pre-reset`) are *contract references*: mine
  them for intended behavior, then translate valuable cases into new tests.
  Never copy old tests that merely encode the old architecture.

## 6. Feature-creep policy

Default answer to new features is **no**. No achievements, gamification,
dashboards, social features, analytics, cloud sync, or accounts unless
explicitly justified by the product specs or later beta feedback (clustered
and reviewed first). When uncertain: prefer deleting unnecessary things.

## 7. Licensing discipline

- We are a GPL-3.0 fork: preserve `LICENSE`/`COPYING.md` and copyright
  notices whenever trimming Lichess code.
- chessrs (GPL): attribution if adapting; prefer reimplementation.
- listudy (AGPL): behavior only, never code.

## 8. Chess-domain references

When solving PGN-tree, repertoire-training, or SRS problems, inspect the
reference repositories first (see `docs/INTEGRATION_MAP.md` for what to take
and what to ignore):

- https://github.com/ZackMurry/chessrs (SRS scheduling, review queues)
- https://github.com/ArneVogel/listudy (study trees, training variations)

Do not invent a third architecture when proven behavior exists. Also check
Lichess Mobile's own `model/study/` and `model/common/node.dart` — the
foundation already contains study-tree and game-tree prior art.

## 9. Cut discipline (Phase 1 and beyond)

- Follow `CUT_PROPOSALS.md`; do not silently make controversial cuts.
- One subsystem per commit; after each cut: `./verify` + launch + smoke run.
- Trace dependencies before deleting: a removed feature may leave a reusable
  primitive (filter widget, avatar, sheet) that other survivors need.
- Keep GPL notices of any removed-origin code that still shares files.
