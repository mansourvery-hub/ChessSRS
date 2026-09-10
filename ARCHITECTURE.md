# Technical Architecture

## 1. Architectural Style

Chess Repertoire SRS is built as a **local-first, layered, modular system** designed for zero perceived latency during review and forward-compatibility with asynchronous cloud synchronization.

---

## 2. Layer Hierarchy & Boundaries

```text
┌────────────────────────────────────────────────────────┐
│                   Presentation / UI                    │
│            (Flutter Widgets, Board, Prompts)           │
└───────────────────────────┬────────────────────────────┘
                            │
┌───────────────────────────▼────────────────────────────┐
│                   Application Layer                    │
│             (ReviewService, ImportService)             │
└─────────────┬────────────────────────────┬─────────────┘
              │                            │
┌─────────────▼──────────────┐ ┌───────────▼─────────────┐
│        Domain Layer        │ │       Chess Layer       │
│  (Study, Chapter, Tree,    │ │ (ChessService, Parser,  │
│   Decisions, SRS States)   │ │  PGN Normalization)     │
└─────────────▲──────────────┘ └───────────▲─────────────┘
              │                            │
┌─────────────┴────────────────────────────┴─────────────┐
│                   Persistence Layer                    │
│      (StudyRepository, InMemory, Local File Store)     │
└────────────────────────────────────────────────────────┘
```

### Boundary Invariants

1. **Pure Domain**: The domain layer (`lib/domain/`) contains pure Dart logic and entity models. It has **zero dependencies** on Flutter UI packages (`flutter/material.dart`, widgets) and zero dependencies on database engines or external chess package internals.
2. **Encapsulated Chess Engine**: External chess rule packages (e.g. `package:chess`) are strictly encapsulated within `lib/chess/chess_service.dart`. Domain entities and UI components interact only via normalized value objects (`PositionKey`, `RepertoireMove`, `ChessMove`).
3. **Local-First Critical Path**: The move-validation loop (`user move -> legality -> repertoire match -> SRS update -> board update`) is executed completely in memory and synchronously saved locally. Network access is never placed on this path.

---

## 3. Component Responsibilities

### Domain Layer (`lib/domain/`)
- **`Study` & `Chapter`**: Root content containers representing imported repertoire collections and individual chapters/lines.
- **`PositionNode`**: Nodes in the position tree containing normalized FEN keys, incoming moves, annotations, comments, and recursive child branches.
- **`RepertoireDecision`**: The primary learning unit representing a position where the player must recall their prepared repertoire move.
- **`ReviewState` & `ReviewEvent`**: Spaced repetition tracking (streak, lapses, stability, next due timestamp) and immutable review logs.
- **`Scheduler` & `SimpleScheduler`**: Contract and default interval ladder for computing SRS transitions.
- **`Clock`**: Time abstraction enabling deterministic testing of time-dependent review intervals.

### Chess Layer (`lib/chess/`)
- **`ChessService`**: Adapter wrapping the rules engine. Performs SAN resolution, legal move generation, coordinate conversions (from/to/promotion), and FEN generation without leaking package types.
- **`PgnParser`**: Tokenizer and recursive-descent parser for raw PGN movetext supporting multi-game files, comments, NAGs, and recursive variations (RAV).
- **`PgnConverter`**: Walks parsed PGN ASTs with `ChessService` to produce validated `PositionNode` trees.

### Import Layer (`lib/import/`)
- **`ImportService`**: Orchestrates raw PGN splitting, parsing, tree normalization, and chapter generation with detailed error/warning accumulation.

### Persistence Layer (`lib/persistence/`)
- **`StudyRepository`**: Interface defining contracts for persisting studies, chapters, position trees, decisions, review states, and review events.
- **`InMemoryStudyRepository`**: Fast in-memory implementation for test suites and initial state management.

### Application Layer (`lib/application/`)
- **`ReviewService`**: Application coordinator that queries due decisions across studies, validates submitted user moves, updates SRS records, and determines next positions.

---

## 4. Entity Identity & Position Model

- **Stable Entity IDs**: All entities (`Study`, `Chapter`, `PositionNode`, `RepertoireDecision`, `ReviewState`) use UUID v4 strings for globally unique, sync-ready identification.
- **Position Key Normalization**: Position keys are derived from normalized 4-field FEN segments (piece placement, side-to-move, castling rights, and en-passant square) ensuring full chess state fidelity.

---

## 5. Review Engine State Machine

```text
               ┌───────────────┐
               │ Select Scope  │
               └───────┬───────┘
                       │
                       ▼
               ┌───────────────┐
               │ Due Decision? ├─── No ───► Show Idle Screen
               └───────┬───────┘
                       │ Yes
                       ▼
               ┌───────────────┐
               │ Show Position │
               └───────┬───────┘
                       │
                       ▼
               ┌───────────────┐
               │ User Plays SAN│
               └───────┬───────┘
                       │
         ┌─────────────┴─────────────┐
         ▼                           ▼
   [Correct Move]             [Incorrect Move]
         │                           │
  • Record success            • Record lapse
  • Update SRS (+interval)    • Update SRS (reset streak)
  • Auto-traverse non-due     • Reveal expected move
         │                           │
         └─────────────┬─────────────┘
                       │
                       ▼
               ┌───────────────┐
               │ Next Due Node │
               └───────────────┘
```
