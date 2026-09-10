# Agent Operating Guidelines & Authority Hierarchy

## 1. The Authority Hierarchy

When working in this repository, follow this strict authority hierarchy:

```text
PRODUCT.md
    ↓ (Defines product vision, user journeys, functional & UX requirements)
MVP.md
    ↓ (Defines current active MVP scope, included/excluded capabilities)
ARCHITECTURE.md
    ↓ (Defines technical structure, layer boundaries, and component roles)
QUALITY.md
    ↓ (Defines non-negotiable engineering, domain, and performance invariants)
TEST_STRATEGY.md
    ↓ (Defines how invariants are mechanically proven through automated gates)
IMPLEMENTATION_PLAN.md
    ↓ (Defines task dependency graph, current tasks, and execution status)
AGENTS.md
    ↓ (Explains how an agent navigates and operates within all of the above)
```

**Rule**: Code implements specifications. Code is not the specification. If requirements or architectural boundaries change, update the authoritative specification documents accordingly.

---

## 2. The Development Loop

Every engineering task in this repository must follow the continuous development loop:

```text
1. SELECT READY TASK
   - Read IMPLEMENTATION_PLAN.md and pick an unblocked task whose dependencies are complete.

2. UNDERSTAND THE SPECIFICATION
   - Read relevant sections in PRODUCT.md, MVP.md, ARCHITECTURE.md, and QUALITY.md.

3. DEFINE SMALL CONTRACT
   - Break down the task into small, testable validated bricks.

4. WRITE TEST FIRST / WITH CONTRACT
   - Add targeted unit/integration tests verifying the brick.

5. IMPLEMENT
   - Write minimal, clean, idiomatic Dart/Flutter code satisfying the contract.

6. TARGETED VERIFICATION
   - Run the specific test suite (e.g. `flutter test test/specific_test.dart`).

7. FULL LOCAL QUALITY GATE
   - Run `./verify` to ensure zero analysis warnings and 100% passing tests.

8. HANDLE FAILURES / REGRESSIONS
   - If a bug is discovered, diagnose root cause, fix, and write a permanent regression test.

9. UPDATE STATE & DOCUMENTATION
   - Mark task status in IMPLEMENTATION_PLAN.md.
   - Update ARCHITECTURE.md or QUALITY.md if technical boundaries or invariants changed.

10. COMMIT & PUSH
    - Create clean, atomic Git commits matching repository conventions.
```

---

## 3. Mandatory Quality Gate

Before completing any task or declaring work done, execute:

```bash
./verify
```

The `./verify` script runs:
1. `flutter analyze` (Static typing, lint rules, zero warnings policy).
2. `flutter test` (Full automated test suite).

---

## 4. Inspiration & Prior Art References

When solving domain-specific chess problems (PGN variation parsing, tree navigation, SRS scheduling), inspect:
- `https://github.com/ZackMurry/chessrs` (Opening SRS concepts, review queues)
- `https://github.com/ArneVogel/listudy` (Study trees, training variations)
- See `docs/inspiration.md` for context.
