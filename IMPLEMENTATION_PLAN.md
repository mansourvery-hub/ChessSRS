# Implementation Plan & Task Graph

This document defines the structured implementation tasks, their dependency relationships, and the current execution state for the Chess Repertoire SRS application.

---

## 1. First-Class Task Dependency Graph

```text
               ┌──────────────────────────────┐
               │ T1: Project Shell & Tooling  │
               └──────────────┬───────────────┘
                              │
               ┌──────────────┴──────────────┐
               │                             │
               ▼                             ▼
┌──────────────────────────────┐ ┌──────────────────────────────┐
│     T2: Core Domain Model    │ │  T3: Chess Rules Adapter     │
│   (Study, Chapter, Tree)     │ │   (Legal moves, FEN, SAN)    │
└──────────────┬───────────────┘ └───────────┬──────────────────┘
               │                             │
               └──────────────┬──────────────┘
                              │
               ┌──────────────┴──────────────┐
               │                             │
               ▼                             ▼
┌──────────────────────────────┐ ┌──────────────────────────────┐
│  T4: PGN Parser (RAV Trees)  │ │  T5: SRS Scheduling Engine   │
│  (Tokenization, variations)  │ │   (Scheduler, ReviewState)   │
└──────────────┬───────────────┘ └───────────┬──────────────────┘
               │                             │
               └──────────────┬──────────────┘
                              │
                              ▼
               ┌──────────────────────────────┐
               │  T6: PGN Import Normalizer   │
               │   (Study graph generation)   │
               └──────────────┬───────────────┘
                              │
                              ▼
               ┌──────────────────────────────┐
               │    T7: Review Application    │
               │ (Due selection, validation)  │
               └──────────────┬───────────────┘
                              │
                              ▼
               ┌──────────────────────────────┐
               │ T8: Local Persistence Store  │
               │  (Repository interfaces/impl)│
               └──────────────┬───────────────┘
                              │
                              ▼
               ┌──────────────────────────────┐
               │     T9: Review-First UI      │
               │  (Chessboard, Recall Loop)   │
               └──────────────┬───────────────┘
                              │
                              ▼
               ┌──────────────────────────────┐
               │  T10: Complete Verification  │
               │   (Test suites & ./verify)   │
               └──────────────────────────────┘
```

---

## 2. Task Definitions & Status

### Completed MVP Slices

- [x] **T1 — Project Shell & Tooling Baseline**
  - **Contract**: Scaffold Flutter project with FVM (Flutter 3.47.2 / Dart 3.13.2) supporting mobile, desktop, and web; configure `analysis_options.yaml` and dependencies (`chess`, `uuid`, `equatable`, `clock`, `path_provider`, `shared_preferences`).
  - **Verification**: `flutter analyze` passes.

- [x] **T2 — Core Domain Model**
  - **Contract**: Define immutable domain entities (`Study`, `Chapter`, `PositionNode`, `PositionKey`, `RepertoireMove`, `RepertoireDecision`) with zero Flutter/third-party package dependencies.
  - **Verification**: Type system validation and constructor immutability checks.

- [x] **T3 — Chess Rules Adapter**
  - **Contract**: Build `ChessService` encapsulating chess rules, legal move generation, coordinate conversions, and resilient SAN resolution.
  - **Verification**: `test/chess_service_test.dart` (7/7 tests passed).

- [x] **T4 — PGN Parser with Recursive Variations**
  - **Contract**: Build `PgnParser` tokenizing movetext, parsing multi-game splits, headers, comments, NAGs, and recursive variation subtrees.
  - **Verification**: `test/pgn_parser_test.dart` (6/6 tests passed).

- [x] **T5 — SRS Scheduling Engine**
  - **Contract**: Implement `Scheduler` abstraction and `SimpleScheduler` with exponential interval growth, lapse recovery, and injectable `Clock` for deterministic testing.
  - **Verification**: `test/srs_scheduler_test.dart` (4/4 tests passed).

- [x] **T6 — PGN Import Normalization Pipeline**
  - **Contract**: Implement `PgnConverter` and `ImportService` to normalize parsed PGN games into complete `Study` hierarchies with position nodes and structured error reporting.
  - **Verification**: `test/import_service_test.dart` (4/4 tests passed).

- [x] **T7 — Review Application Coordinator**
  - **Contract**: Implement `ReviewService` and `ReviewEngine` managing due decision discovery, answer verification, auto-continuation through learned moves, and SRS state progression.
  - **Verification**: `test/review_service_test.dart` (2/2 tests passed).

- [x] **T8 — Local Persistence Store**
  - **Contract**: Implement `StudyRepository` interface and `InMemoryStudyRepository` storing studies, position trees, decisions, and review state/event histories.
  - **Verification**: Service integration tests with persistence assertions.

- [x] **T9 — Review-First UI Scene**
  - **Contract**: Implement Flutter application startup directly into the Review scene with responsive board rendering, algebraic move input, feedback display, and progression.
  - **Verification**: `test/widget_test.dart` smoke test.

- [x] **T10 — Quality Gate & Automated Verification**
  - **Contract**: Create executable `./verify` script running full static analysis and automated test suite.
  - **Verification**: `./verify` passes with 0 issues and 24/24 tests passed.

---

## 3. Next Evolution Tasks (Phase 2 Roadmap)

- [ ] **T11 — Drag-and-Drop Interactive Board Controls**
  - Add piece dragging and square tap-tap interaction replacing text move input.
- [ ] **T12 — File Picker & System Import UI**
  - Add file import dialogs on desktop and mobile platforms.
- [ ] **T13 — Local SQLite/Drift Persistence Adapter**
  - Replace in-memory repository default with durable local SQLite storage.
- [ ] **T14 — Cross-Study Opening Selector Drawer**
  - Enable filtering review scope by study or cross-study opening classification.
