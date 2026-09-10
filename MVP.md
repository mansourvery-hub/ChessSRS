# MVP Scope & Specifications

## 1. MVP Goal

Deliver a functional, local-first Flutter application (mobile, desktop, web) that executes the complete loop:
**PGN Import → Normalized Repertoire Tree → Active Review Scene → Local SRS Persistence**.

---

## 2. Included Capabilities

| Capability | Description | Status |
|---|---|---|
| **Local PGN Import** | Multi-game, multi-chapter PGN parser supporting recursive variations (RAVs), comments, NAGs, and starting FENs. | Complete |
| **Repertoire Normalization** | Converts PGN trees into domain `Study` → `Chapter` → `PositionNode` graphs with deterministic FEN keys. | Complete |
| **Decision Point Derivation** | Derives `RepertoireDecision` units for positions requiring user recall. | Complete |
| **Active Recall Review** | Interactive chessboard scene where users input moves to answer due repertoire positions. | Complete |
| **Move Validation** | Immediate local validation against expected repertoire continuation moves. | Complete |
| **Automatic Traversal** | Automated traversal through opponent replies and already-learned user moves until the next due decision. | Complete |
| **Replaceable SRS Scheduler** | `Scheduler` contract + `SimpleScheduler` exponential interval ladder with lapse recovery and deterministic testing support. | Complete |
| **Local Persistence** | `StudyRepository` interface with `InMemoryStudyRepository` and file-backed persistence. | Complete |
| **Cross-Platform Support** | Flutter codebase supporting Linux, macOS, Windows, Android, iOS, and Web. | Complete |

---

## 3. Excluded Capabilities (Deferred to Later Phases)

```text
PRODUCT SCOPE
├── Local PGN Import               [MVP]
├── Recursive Variation Trees      [MVP]
├── Review-First Active Recall     [MVP]
├── Automatic Traversal            [MVP]
├── Replaceable SRS Engine         [MVP]
├── Local Persistence              [MVP]
├── Advisory Engine Health Check   [Phase 2]
├── Cross-Study Opening Filter     [Phase 2]
├── Lichess OAuth & Study Sync     [Phase 3]
├── Cross-Device Cloud Sync        [Phase 4]
└── Tactics / Social / Gamify      [EXCLUDED]
```

---

## 4. Acceptance Criteria

1. **Clean Import**: Importing a PGN containing multiple chapters and nested variations produces a fully intact hierarchy where no variation branch is discarded.
2. **Deterministic Correctness**: Playing a move that matches an active repertoire branch is accepted immediately; playing any other move (even legal chess moves) is marked incorrect.
3. **SRS Interval Progression**:
   - New items are due immediately upon creation.
   - Successful recalls increase the interval (1 day → 2 days → 4 days → ...).
   - Failed recalls reset the repetition streak and schedule a short-interval retry.
4. **Zero-Lag Interaction**: Move legality and repertoire lookup happen synchronously in memory without blocking UI rendering.
5. **No Modal Interruptions**: Incorrect moves reveal the expected line and allow progression without requiring modal dismissals.
6. **Persistence Durability**: Review states and study structures survive application restarts.

---

## 5. Known Limitations (MVP)

- Default player orientation heuristic is White unless specified in chapter metadata or custom FEN.
- UI uses clean Unicode chess glyphs on a responsive board grid; custom SVG vector sets will be refined in UI polishing iterations.
