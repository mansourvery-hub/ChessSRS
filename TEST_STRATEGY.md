# Verification & Testing Strategy

This document defines **how the invariants and properties in `QUALITY.md` are mechanically proven** through automated tests, static analysis, and quality gates.

---

## 1. Quality Invariant Enforcement Matrix

| Invariant / Property in `QUALITY.md` | Enforcement Mechanism | Test Target |
|---|---|---|
| **Layer Independence & Clean Architecture** | Static analysis / linter (`flutter analyze`) | All files in `lib/` |
| **Encapsulation of Chess Package Types** | Type checking / linter | `lib/domain/`, `lib/application/` |
| **Legal Move Validation & SAN Resolution** | Unit tests (`test/chess_service_test.dart`) | `ChessService` |
| **PGN Multi-game & Variation Preservation** | Unit tests (`test/pgn_parser_test.dart`) | `PgnParser` |
| **Study Tree Normalization & Error Reporting** | Integration tests (`test/import_service_test.dart`) | `ImportService`, `PgnConverter` |
| **SRS Interval Growth & Lapse Recovery** | Deterministic unit tests (`test/srs_scheduler_test.dart`) | `SimpleScheduler`, `ReviewState` |
| **Repertoire Answer Validation & Persistence** | Service tests (`test/review_service_test.dart`) | `ReviewService`, `InMemoryStudyRepository` |
| **Review-First UI Rendering** | Widget smoke tests (`test/widget_test.dart`) | `ChessRepertoireApp` |
| **Complete Mandatory Quality Gate** | Executable script | `./verify` |

---

## 2. Test Suite Organization

```text
test/
├── chess_service_test.dart    # Legal moves, coordinate conversions, SAN parsing, promotion, castling, en-passant
├── pgn_parser_test.dart       # Movetext tokenization, multi-game splitting, recursive variations, comments, NAGs
├── import_service_test.dart   # End-to-end PGN import -> Study/Chapter/PositionNode graph, error handling
├── srs_scheduler_test.dart    # Fixed clock tests for initial due, interval scaling, lapse streak resets
├── review_service_test.dart   # Repertoire validation, due decision collection, review state persistence
└── widget_test.dart           # Flutter widget smoke tests verifying Review scene startup
```

---

## 3. Verification Levels & The Quality Gate

### Level 1: Targeted Brick Check
During development of a specific function or contract, run only the targeted test file:
```bash
flutter test test/chess_service_test.dart
```

### Level 2: Full Local Quality Gate (`./verify`)
Before committing or marking a task complete, run the mandatory local quality gate:
```bash
./verify
```
The `./verify` script executes:
1. `flutter analyze` (Static type-checking, linter compliance, zero warnings).
2. `flutter test` (Full automated test suite execution).

### Level 3: Continuous Integration (CI)
On every pull request and push to `main`, GitHub Actions runs `./verify` in a clean environment to ensure zero regression across platforms.
