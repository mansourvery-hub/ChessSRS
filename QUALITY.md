# Quality & Engineering Invariants

This document defines the **non-negotiable properties, constraints, and
invariants** that must be maintained across all implementations, refactorings,
and feature additions in Chess Repertoire SRS.

> Layer names refer to the Lichess-Mobile-foundation architecture described in
> `ARCHITECTURE.md` (presentation / application / our domain / infrastructure).
> The invariants themselves are implementation-agnostic and carried over
> verbatim from the product reset.

---

## 1. Architectural Invariants

1. **Layer Independence**:
   - The Presentation layer (Lichess `view/` + our review scene) must never
     directly interact with database tables, raw storage blobs, or chess
     library internals; it talks to application providers only.
   - Our Domain layer must remain pure Dart with **zero imports** of Flutter
     widget libraries (`package:flutter/...`), chessground, or sqflite.
2. **Single Chess Representation**:
   - `dartchess` is the only chess rules engine. Never introduce a competing
     chess library or a second internal representation of moves, positions, or
     games. chessground is a presentation consumer of dartchess state.
3. **Local-First Zero-Latency Review**:
   - The critical review loop (`user move submission -> move validation ->
     SRS update -> board update`) must execute entirely in memory and locally.
   - Network calls are strictly forbidden on the critical path of move
     submission and board rendering.
4. **Advisory Engine Isolation**:
   - If an engine analysis pass is introduced (e.g. at import), it must run
     asynchronously outside the review loop and remain purely advisory. An
     engine evaluation must never veto or block the user's repertoire import.

---

## 2. Domain & Chess Invariants

1. **Repertoire Correctness over Engine Truth**:
   - Correctness during Review is strictly defined by the user's repertoire
     material, not engine evaluation.
   - Opponent inaccuracies and mistakes are valid repertoire content (intended
     to teach prepared punishments).
2. **Variation Preservation**:
   - PGN import must preserve recursive annotation variations (RAVs) as
     first-class sibling branches under their respective parent nodes.
   - Variations must never be flattened or silently deleted during parsing or
     conversion.
3. **Position Identity Integrity**:
   - A position's identity must account for piece placement, active side to
     move, castling availability, and en-passant target square (normalized
     4-field FEN; the "clean FEN").
4. **Long-Term Retrieval (No Permanent Exclusion)**:
   - A learned move that is auto-traversed during non-due intervals is **never
     permanently excluded** from review. It must become an active question
     again once its scheduled due date arrives.

---

## 3. Reliability & Error Invariants

1. **Graceful Degradation over Silent Corruption**:
   - Malformed PGN moves or invalid headers must be quarantined with
     structured error messages (containing chapter title and move index)
     rather than crashing the importer or silently creating broken position
     graphs.
2. **Deterministic Time Testing**:
   - All time-dependent domain logic (SRS scheduling, due item queries) must
     accept an abstract `Clock` instance so test suites can run
     deterministically without depending on system wall-clock time.

---

## 4. Performance Invariants

1. **Move Response Time**: Local move legality validation and repertoire
   lookup must complete in **< 16 milliseconds** (within a single display
   frame).
2. **Incremental State Writes**: Review state updates must be persisted
   incrementally without rewriting the entire study tree on every move.
