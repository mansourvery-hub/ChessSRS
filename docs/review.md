# Review Engine and SRS

## Purpose

Turn repertoire content into an immediate active-recall loop.

The engine must answer:

1. What should be shown next?
2. Which repertoire move(s) are expected?
3. Is the submitted move accepted?
4. What happens next?
5. How does the result update SRS?

## Review loop

```text
select scope
 -> select due/reviewable decision
 -> show position
 -> user plays move
 -> local legality + repertoire check
 -> immediate feedback
 -> update review state
 -> traverse known continuation
 -> next due decision
```

## Correctness

A move is correct when it matches an accepted repertoire continuation for the active Review scope.

Do not use engine evaluation to decide Review correctness in MVP.

Opponent moves are content. They are not required to be engine-best.

## Automatic traversal

If a decision is currently not due, the engine may traverse it automatically for either side as appropriate.

Automatic traversal means:

`not currently tested`

not:

`never test again`

A previously auto-played decision must become testable again when its SRS state becomes due, even after a very long interval.

## Due selection

Default scope: all studies.

Selection should favour due items. The exact ordering can evolve, but it must be deterministic enough to test.

Potential ordering dimensions:

- due time
- overdue amount
- study/chapter order
- randomization

Do not add complex prioritization until user value is demonstrated.

## Multiple repertoire answers

If a node contains multiple accepted repertoire branches, Review may accept any branch marked as active for the current scope.

The system must know which branch the user entered so subsequent traversal follows the corresponding continuation.

## Failure behaviour

On an incorrect move:

- respond immediately
- reveal or demonstrate the expected move according to the visual design
- record a failed recall
- continue the line without requiring modal dismissal

Exact feedback animation belongs in `docs/design.md`.

## SRS abstraction

Use a replaceable scheduler contract conceptually equivalent to:

```text
schedule(previousState, reviewResult, timestamp) -> newState
```

Do not embed scheduling formulas inside UI code or database queries.

## MVP scheduler

A simple scheduler is acceptable initially. It must support intervals long enough for items to disappear from daily review and later return.

The implementation should not bake in a maximum interval that prevents long-term return.

## Future scheduler

A more sophisticated algorithm such as FSRS may be introduced later. Migration must be possible without changing the Review UI or repertoire tree model.

## No session completion

Review has no mandatory session boundary. Users can stop at any time.

## Review state durability

After a move result, persist the state locally before the item can be lost due to app closure where practical. Do not block the visible move interaction on network sync.
