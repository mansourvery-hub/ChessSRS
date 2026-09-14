# Product Definition

## 1. Vision & Core Value

**Chess Repertoire SRS** is a focused, local-first chess learning application for **memorizing and retaining opening and middlegame repertoires through active spaced repetition**.

The core premise:
> **Show the player a position from their own repertoire and ask them to play what they have learned.**

The application is not a general tactics trainer, an engine analysis cockpit, or a social network. Its purpose is to turn a player's curated repertoire material into **instant, reliable, retrievable memory**.

---

## 2. Target Users

- **Tournament and competitive chess players** preparing structured opening repertoires.
- **Club players and students** who study PGN files or coach-provided material and need to remember lines under game conditions.
- **Players tired of feature bloat** who want a minimal, zero-latency review utility that opens directly into active practice.

---

## 3. Core User Journeys

### Journey 1: Daily Repertoire Review (Default)
1. User opens the application.
2. The app immediately presents the chessboard on the first due position across all imported studies.
3. User recalls and makes their prepared move on the board.
4. If correct: subtle positive feedback, automatic traversal through already-learned opponent/user continuations, and stopping at the next due decision.
5. If incorrect: immediate subtle feedback showing the expected repertoire continuation, recording a failed recall, and advancing.
6. User reviews as long as they wish; when all items are up to date, a calm idle state is displayed.

### Journey 2: First Launch & PGN Import
1. User opens the app for the very first time (zero studies exist).
2. The app presents a clean, focused import interface.
3. User supplies a PGN file containing one or many games/chapters with variations, comments, and annotations.
4. The system validates chess legality, preserves full variation trees, normalizes chapters, and derives scheduled decision points.
5. User is immediately transitioned into Review of the newly imported material.

### Journey 3: Constrained Review Scope
1. User is preparing for a specific match (e.g. against 1.e4) and wants to focus on their Sicilian repertoire.
2. User opens the lightweight study/opening filter drawer.
3. User selects the target study or opening category.
4. The Review scene updates its active pool to only test due positions matching that filter.

---

## 4. Functional Requirements

1. **PGN Pipeline**:
   - Accept standard and non-standard PGNs with single or multiple games/chapters.
   - Preserve recursive annotation variations (RAVs) as first-class branching trees.
   - Support arbitrary starting FEN positions.
   - Extract move comments and NAGs without corrupting tree structure.

2. **Repertoire Training Model**:
   - Training evaluates whether the player remembered **their repertoire**, not whether the move is engine-optimal.
   - Opponent mistakes and prepared punishments are first-class repertoire content.
   - Player decision points are derived for the user's perspective.

3. **Spaced Repetition System (SRS)**:
   - Every repertoire decision maintains its own SRS state (repetition count, lapse count, stability/interval, next due timestamp).
   - Non-due (already learned) positions are automatically traversed during review so the user is only tested on what is currently due.
   - Previously learned moves return as active testable questions once their interval elapses.
   - Scheduler algorithm is replaceable behind an abstract contract.

4. **Offline & Performance**:
   - The entire review and move-validation loop is 100% local and requires zero network access.
   - Perceived interaction latency must be effectively zero (<16ms on mobile and desktop).

---

## 5. UX & Design Principles (Dogmatic Minimalism & Lichess Professional Polish)

- **The Product is Review**: The chessboard is the primary and dominant interface element, accompanied by a professional move history sidebar and study navigator.
- **Quiet & Fast Feedback**: Move confirmation is immediate with subtle tactile/audio feedback cues and clean status banners.
- **Lichess Design Standards**: Calibrated dark theme (`#161512` background, `#262421` surface, `#629924` accent), SVG chess pieces, clean algebraic notation tree with variant folding, and responsive desktop split view.
- **No Mandatory Session Boundary**: Review is an ongoing utility. Users can stop anytime without penalty.
- **Restrained Visual Aesthetic**: Subtle typography, generous negative space, high-contrast board pieces, no gamer aesthetics.

---

## 6. Non-Goals (Explicit Exclusions)

- No tactics puzzle generator or arbitrary position solver.
- No real-time chess engine judging review moves (engine evaluation does not dictate repertoire correctness).
- No multiplayer, matchmaking, or social leaderboards.
- No mandatory daily gamification streaks or XP badges.
- No cloud dependency for core move validation.

---

## 7. Future Horizons (Post-MVP)

- **Lichess Integration**: Authenticate and directly import/sync user's Lichess studies.
- **Cross-Device Async Sync**: Background synchronization of study content and SRS review history across mobile, web, and desktop.
- **Advisory Import Health Check**: Optional asynchronous one-time engine pass warning users of severe evaluation collapses in their own lines (advisory only, never blocking).
- **Cross-Study Opening Categorization**: Aggregate repertoire positions by opening family across separate study files.
