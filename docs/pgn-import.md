# PGN Import

## Goal

Convert real-world PGN files into a validated internal study tree without flattening away useful structure.

## Supported concepts

MVP importer should support:

- standard PGN headers
- multiple games/chapters in one file
- main lines
- recursive variations
- starting FEN where valid
- SAN move application
- comments/annotations where preservation is useful
- game/chapter boundaries

Graceful degradation is preferable to silent corruption.

## Pipeline

```text
file bytes
 -> PGN parser
 -> semantic move tree
 -> legal-position validation
 -> normalized Study/Chapter/PositionNode data
 -> Review-item derivation
 -> local persistence
```

Do not bind parsing directly to Flutter widget state or database rows.

## Validation

Reject or quarantine malformed sections rather than creating invalid chess positions.

Import errors should identify the nearest useful location, such as chapter and move number.

Never silently import a partially corrupted tree as if it were complete.

## Variations

Variations are first-class repertoire branches.

Nested variations must remain distinguishable from the main line.

The internal model should not depend on textual parenthesis nesting after normalization.

## Multiple chapters

Each logical game/chapter remains identifiable after import. Preserve source order and title/metadata where available.

A single PGN can therefore produce one Study with many Chapters.

## FEN

A chapter may begin from a non-standard starting position. The imported root must use the correct full chess state.

## Comments/annotations

Preserve data that can support future UX, analysis warnings, or study editing. MVP does not need to render every PGN annotation.

## Import result

The importer should return a structured result that can distinguish:

- success
- warnings
- fatal errors
- counts (chapters, branches, decisions) where useful

## Future engine warning pass

A future import pipeline can insert:

```text
normalize -> optional user-side engine analysis -> warnings -> import
```

The warning pass must never reject a study solely because a user-selected move has a poor engine evaluation.

## Future input sources

Lichess should feed the same normalized import model. Do not create a separate Lichess-only Study representation.
