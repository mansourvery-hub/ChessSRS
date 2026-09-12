# Review Engine Implementation Plan

Based on analysis of reference implementations (chessrs, listudy), here's the behavior to implement:

## Key Behaviors from chessrs (PracticeMainPanel.tsx)

1. **Move Queue**: Fetches a queue of positions to practice (random moves from backend)
2. **Move Validation**: 
   - Compares user's move SAN with expected move SAN
   - If correct: advances to next move in queue
   - If wrong: Shows correct move via `wrongMove`, waits 3 seconds, then continues
3. **Queue Management**:
   - When queue has 1 move left, fetches more moves
   - On correct move: removes first item from queue, loads next position
   - On wrong move: Shows correct move via `wrongMove`, waits 3s, resets with `wrongMoveReset`
3. **Auto-continuation**: After correct answer, automatically loads next position
4. **Perspective**: Each position has a perspective (white/black) - loads position with correct perspective

## Key Behaviors from Listudy

1. **Study Tree**: Books → Openings → BookOpenings (many-to-many)
2. Openings have: FEN, moves (PGN), UCI moves, ECO code
3. Openings can be trained via Phoenix LiveView
3. Uses Phoenix LiveView for real-time interaction
4. Studies → Books → Openings structure

## Required Behavior for Chess Repertoire SRS

### Review Engine State Machine

```
Select Scope → Find Due Decision → Show Position → User Plays Move
                                                              │
                    ┌─────────────────────────────────────────┘
                    ▼
            ┌───────────────┐
            │ Correct?      │
            └───────┬───────┘
                    │
          ┌─────────┴─────────┐
          ▼                   ▼
    CORRECT              INCORRECT
          │                   │
   Record Success       Record Failure
   Update SRS (+interval) Update SRS (reset streak, short interval)
   Advance to next      Reveal expected move
   Auto-traverse        Continue line
   non-due              Stop at next due
          │                   │
          └─────────┬─────────┘
                    ▼
           Next Due Decision
```

### Automatic Continuation Logic

1. After correct answer: advance to child node
2. Check if child node has a due decision:
   - If due: STOP - this becomes the next prompt
   - If NOT due: auto-play the best repertoire move, continue to next node
3. Continue until reaching a due decision or end of line

### Branch Handling

- A PositionNode can have multiple children (variations)
- Each child represents a valid repertoire continuation
- Review should accept ANY valid child move
- After user plays a move, follow that specific branch

## Implementation Plan

### 1. Fix ReviewEngine (lib/domain/review_engine.dart)

Add proper state machine with:
- `ReviewSession` class to manage a review session
- `advance()` method that handles automatic continuation
- Proper handling of correct/incorrect answers
- Automatic continuation through non-due positions

### 2. Update ReviewService

- Use ReviewEngine for core logic
- Add study-scoped review support
- Handle decision creation from PositionNode tree

### 3. Fix ReviewEngine auto-continuation

The current `applyMoveAndAdvance` is incomplete. Need to implement:
- After correct move: find child, check if due, if not due auto-advance
- After incorrect: record failure, show expected, continue

### 4. Decision Creation from PositionNode

Current implementation creates decisions at ALL non-leaf nodes. Should only create at:
- User's turn positions (where side to move matches user's repertoire color)
- Positions with repertoire moves (childMoves not empty)

### 5. Automatic Continuation Logic

After correct answer:
1. Get child node for the played move
2. While child exists and child is NOT due (or not a decision point):
   - If child is opponent's turn: auto-play best repertoire move
   - If child is user's turn but not due: auto-play repertoire move
   - Move to next node
3. Stop when reaching a due decision point or end of line

## Files to Modify

1. `lib/domain/review_engine.dart` - Core review engine with state machine
2. `lib/application/review_service.dart` - Update to use ReviewEngine properly
3. `lib/domain/review_engine.dart` - Add ReviewSession class
3. `lib/application/review_service.dart` - Use ReviewEngine properly
4. `lib/main.dart` - Update UI to use proper review flow
4. Add tests for new behavior

Let me start implementing.