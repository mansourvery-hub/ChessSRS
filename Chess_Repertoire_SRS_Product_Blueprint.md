# Chess Repertoire SRS
## Product Blueprint — v0.2
> Agents: do not read this file by default. Start with `AGENTS.md` and the
> relevant subsystem document; consult this file only when they do not answer.

---

# 1. Product vision

Chess Repertoire SRS is a focused chess-learning application for **memorizing and retaining opening and middlegame repertoires through spaced repetition**.

The core idea is simple:

> **Give the player a position from their own repertoire and ask them to play what they have learned.**

The application is not a tactics trainer, a conventional engine-analysis application, or a general-purpose chess study platform.

Its purpose is to turn a player's existing repertoire material into **reliable, retrievable memory**.

The primary input is a PGN. A PGN may contain one study, many chapters, many games, and arbitrary variations. The application converts that material into a structured repertoire and continuously presents the player with positions that need to be recalled.

The long-term vision is for the same experience to work seamlessly with Lichess:

> **Import your studies today. Connect your Lichess account tomorrow. Review everywhere.**

---

# 2. Product philosophy

The application should be unusually opinionated.

## 2.1 The product is Review

The product fundamentally has **one main scene: Review**.

There should not be a traditional app structure with:

- Home
- Dashboard
- Training
- Statistics
- Studies
- Settings

as equal destinations.

The chessboard and the act of recalling repertoire are the product.

Studies and opening selection are simply ways of choosing what the Review scene should contain.

Conceptually:

```text
                    REVIEW
                      │
          ┌───────────┼───────────┐
          │           │           │
       all due     one study   one opening
                                  │
                              e.g. Sicilian
```

A user should be able to open the application and immediately start reviewing.

On first launch, when no studies exist, the Review scene should instead present the import action.

This is **dogmatic minimalism by design**.

---

# 3. Core product principles

## 3.1 Instant

The application should feel instantaneous during training.

Chess players think ahead while interacting with the board. Any visible delay between:

- touching/grabbing a piece
- dropping a piece
- validating the move
- receiving feedback
- playing the next move
- advancing to the next position

damages the fundamental experience.

The target is:

> **Effectively zero perceived latency.**

The critical training loop must never depend on a network request.

All move validation, repertoire lookup, review state updates, and progression through known material should happen locally.

The user should be able to train without an internet connection.

---

## 3.2 Minimal

The application should expose as little interface as possible.

The board is the dominant visual element.

There should be no pressure to turn the product into:

- a chess social network
- a gamified fitness tracker
- a statistics dashboard
- an engine cockpit
- a study-management suite

The application should feel calm, focused and premium.

---

## 3.3 Personal repertoire first

The user's own studies are the source material.

A study can represent:

- an opening repertoire
- responses to specific openings
- prepared tournament lines
- middlegame plans
- model games
- coach-provided material
- a collection of chapters covering an entire repertoire

The application does not prescribe what the player should learn.

It helps the player remember **what they have chosen to learn**.

---

## 3.4 Recall rather than recognition

The core interaction is active recall:

> **Position → think → play → feedback → continue.**

Reading moves, looking at variations or passively stepping through a study should remain secondary.

The user should interact with the chessboard as if they were playing a real game.

---

## 3.5 Learn my repertoire ≠ find the best move

The application primarily evaluates whether the player remembered the repertoire.

A move outside the player's repertoire can be objectively excellent and still not be the expected answer.

Therefore:

> **Correctness during Review is based on the repertoire being learned, not on engine evaluation.**

This distinction is fundamental to the product.

---

## 3.6 Opponent mistakes are part of the repertoire

The application should not assume that the opponent's moves are supposed to be engine-perfect.

A repertoire can legitimately contain:

```text
Position
 ├── main line
 ├── opponent makes mistake → prepared punishment
 └── alternative opponent line
```

The player is learning how to respond to those moves.

An opponent error therefore remains valid training material.

---

# 4. PGN as the primary source

The MVP should start with one extremely simple proposition:

> **Give me a PGN and let me learn it.**

The application should accept PGNs containing:

- multiple games
- multiple chapters
- variations
- nested variations
- comments
- annotations where useful
- starting FENs
- normal chess metadata

The application should preserve the logical structure of the source material rather than flattening everything into independent games.

A single imported file may therefore become:

```text
Study
├── Chapter 1
│   ├── Line A
│   ├── Line B
│   └── Line C
├── Chapter 2
│   ├── Line A
│   └── Line B
└── Chapter 3
    └── ...
```

The PGN is an input format, not the internal domain model.

---

# 5. Review is the central experience

The Review scene should be the application's default destination.

After the initial import, opening the application should take the player directly to Review.

A typical screen might be approximately:

```text
                    12 due

               ┌─────────────┐
               │             │
               │   CHESS     │
               │   BOARD     │
               │             │
               └─────────────┘

                   Your move
```

The exact amount of information visible should remain extremely small.

The user should not need to navigate to another screen to begin studying.

---

# 6. Review scope selection

The user should normally review all material that is currently due.

However, there should be lightweight ways to constrain Review when desired.

## 6.1 Study selector

A small side menu or drawer can expose the user's studies.

Example:

```text
Review
──────────────

All studies

Studies
  Sicilian Repertoire
  French Defence
  Tournament Prep
  Coach Material
```

Selecting one study means:

> Review due material from this study.

This is particularly useful when the player is preparing for a tournament and wants to cram a specific repertoire.

The study selector should be intentionally secondary to the Review scene.

---

## 6.2 Opening selector

A second conceptual filter is an **Opening** view.

This is not necessarily tied one-to-one to studies.

An opening can span multiple studies.

Example:

```text
OPENINGS

Sicilian
French
Caro-Kann
Queen's Gambit
King's Indian
```

Selecting:

> **Sicilian**

should allow the player to review Sicilian material across all imported studies.

This is particularly useful when the user's repertoire is distributed across multiple PGNs or studies.

The opening system may initially rely on existing PGN metadata and/or chess position classification, with a more sophisticated classification system introduced later.

The important design decision is:

> **Opening is a cross-study review dimension, not a separate content silo.**

---

# 7. Review behaviour

The user encounters a position and plays the repertoire move.

### Correct move

The application should:

1. accept the move immediately;
2. provide subtle feedback;
3. play the expected continuation;
4. continue through already-learned material where appropriate;
5. stop again when the next relevant question is reached.

### Incorrect move

The application should:

1. immediately detect the mismatch;
2. show the expected repertoire move;
3. allow the player to observe/continue the line;
4. update the review state appropriately.

Feedback should be fast and understated.

Large modals, animated success screens and repeated confirmation buttons should be avoided.

---

# 8. Learned moves and automatic continuation

The application should distinguish between **what is currently worth testing** and **what is already sufficiently learned**.

Suppose a line contains:

```text
1.e4 c5
2.Nf3 Nc6
3.d4 cxd4
4.Nxd4 ...
```

If the player already knows several of those decisions according to their SRS state, the application may automatically play some of those moves for the player and/or opponent.

This dramatically reduces repetition of material the user already knows.

However:

> **Automatic continuation is not permanent exclusion.**

A move or position that is currently considered learned may become due again later.

For example, after a sufficiently long interval—potentially even a year—the same decision may return as an active question.

Thus the training system must not permanently mark a move as "known and never ask again".

Instead:

```text
Currently not due
        ↓
automatic continuation

Later becomes due
        ↓
returns as a question
```

This is central to the SRS model.

---

# 9. What exactly is being scheduled?

The conceptual SRS item is a **repertoire decision**.

A position becomes a review item when the player is expected to recall a move from that position.

Therefore the internal system may contain:

```text
Position
    ↓
Expected repertoire move(s)
    ↓
Review item
    ↓
SRS state
```

This is preferable to blindly scheduling every move in every PGN.

The application should aim to schedule **meaningful player decisions**.

The exact heuristics for determining those decision points can evolve over time.

---

# 10. First-import repertoire health check

A future feature should perform an **optional one-time engine analysis when a study is imported**.

This is not part of the normal Review loop.

Its purpose is not to criticize the opponent's play.

Instead, it checks whether the **user's own repertoire contains serious strategic or tactical aberrations**.

For example:

```text
Study line

User chooses a move
      ↓
engine comparison
      ↓
large evaluation swing
      ↓
potential warning
```

A warning might conceptually say:

> "This line appears to turn a winning position into a losing one."

The important behaviour is:

### Warn, do not block.

The player should always be free to import the study anyway.

The application is not attempting to decide what repertoire the player is allowed to maintain.

The import workflow could therefore become:

```text
PGN imported
      ↓
parse + validate
      ↓
optional one-time analysis
      ↓
potential repertoire warnings
      ↓
"Import anyway"
```

### Scope of the analysis

The analysis should primarily concern **moves belonging to the player's side of the repertoire**.

Opponent mistakes should not be flagged simply because they are engine inaccuracies.

The application should happily contain:

```text
Opponent blunders
       ↓
your prepared punishment
```

because that is precisely the sort of thing the repertoire may be designed to teach.

### Architectural consequence

Engine analysis should be isolated from the Review engine.

Review must remain:

```text
local position
→ repertoire lookup
→ immediate response
```

The import analysis can be:

```text
PGN
→ asynchronous analysis
→ stored warnings
```

This keeps engine computation out of the latency-sensitive training path.

---

# 11. SRS system

Every repertoire decision maintains review state.

The system should track information such as:

- first learned date
- last review
- next due date
- successful recalls
- failed recalls
- difficulty/stability data
- review history

The scheduling algorithm should be replaceable.

The MVP can start with a simple scheduler.

A later implementation could adopt a more sophisticated algorithm such as FSRS without requiring a redesign of the rest of the application.

The scheduler should therefore be treated as its own domain component.

---

# 12. No end-of-session experience

There should be **no dedicated "Session Complete" screen**.

The application should avoid creating an artificial session boundary unless a future feature genuinely requires one.

The user simply reviews.

When there is nothing due, the state can remain extremely simple:

```text
Nothing due.

You're up to date.
```

or equivalent minimal messaging.

The user leaves when they want.

This reinforces the idea that Review is an ongoing utility rather than a game level.

---

# 13. Design direction

The visual identity should be based on **dogmatic minimalism**.

The application should feel modern and highly polished without feeling decorative.

## Desired qualities

- restrained typography
- generous negative space
- subtle motion
- high-quality board rendering
- carefully chosen piece sets
- minimal controls
- excellent touch targets
- restrained use of colour
- strong hierarchy
- fast visual response

## Avoid

- gamer aesthetics
- neon colours
- excessive gradients
- XP systems
- leaderboards
- badges
- progress bars everywhere
- dashboard clutter
- unnecessary cards
- modal-heavy workflows

The board should dominate.

---

# 14. Mobile and web

The product should be built mobile-first while supporting the web from the same codebase.

Flutter is a strong candidate because the application is fundamentally an interactive, graphical, stateful interface that benefits from sharing domain logic across mobile and web.

## Mobile

The board should occupy most of the usable screen.

Controls should remain sparse.

The user should be able to play moves naturally with touch.

## Web

The board can have more surrounding space.

A desktop layout may use the additional room for subtle contextual information or a lightweight selector without compromising the central Review experience.

The web application should not become a conventional dashboard merely because more screen space is available.

---

# 15. Performance architecture

Performance is a fundamental product requirement.

The critical interaction path must be entirely local:

```text
User move
   ↓
Local chess validation
   ↓
Immediate board update
   ↓
Immediate repertoire comparison
   ↓
Immediate feedback
   ↓
Local SRS update
   ↓
Next position
```

It must not become:

```text
User move
   ↓
network request
   ↓
server
   ↓
response
   ↓
UI update
```

The player must never feel that they are waiting for the backend to think.

This also means that future cloud synchronization must be asynchronous and non-blocking.

---

# 16. Architecture

The application should be **local-first, modular and synchronization-ready**.

Conceptually:

```text
                    ┌────────────────────┐
                    │    Flutter UI      │
                    │                    │
                    │      REVIEW        │
                    │      Import        │
                    │      Selectors      │
                    └─────────┬──────────┘
                              │
                    ┌─────────▼──────────┐
                    │   Domain Layer     │
                    │                    │
                    │ Study               │
                    │ Chapter             │
                    │ Repertoire Tree     │
                    │ Review              │
                    │ SRS                 │
                    └─────────┬──────────┘
                              │
             ┌────────────────┼──────────────────┐
             │                │                  │
      ┌──────▼──────┐ ┌───────▼────────┐ ┌─────▼──────────┐
      │ Chess       │ │ Local          │ │ Import /       │
      │ Domain      │ │ Persistence    │ │ Analysis       │
      │             │ │                │ │                │
      │ Rules       │ │ Studies        │ │ PGN            │
      │ Positions   │ │ Review state   │ │ Engine check   │
      │ Moves       │ │ History        │ │ Lichess future │
      └─────────────┘ └────────────────┘ └────────────────┘
```

The exact package choices can be decided during implementation.

The boundaries should not.

---

# 17. Domain model

The core concepts should remain independent from UI and persistence.

Likely domain objects:

```text
Study
Chapter
PositionNode
Move
RepertoireDecision
ReviewState
ReviewEvent
Scheduler
Opening
```

Conceptually:

```text
Study
 ├── Chapter
 │    └── PositionNode
 │          ├── Position
 │          ├── candidate repertoire moves
 │          └── children
 │
 └── Chapter
      └── ...
```

A `RepertoireDecision` represents the part that is actually scheduled for recall.

This distinction allows a large move tree to exist without forcing every node to behave as a standalone flashcard.

---

# 18. PGN pipeline

The PGN importer should be completely separated from UI and storage.

Conceptually:

```text
PGN file
   ↓
PGN parser
   ↓
Normalized study representation
   ↓
Validation
   ↓
Optional engine analysis
   ↓
Study import
   ↓
Local database
```

The system should preserve enough information to reconstruct the study structure and training tree.

The importer should support future input sources through a common abstraction:

```text
                    Study Source
                         │
             ┌───────────┼───────────┐
             │           │           │
            PGN       Lichess     Future API
             │           │
             └───────────┴───────────┘
                         ↓
                  Internal Study
```

This is important because Lichess should eventually become another source of studies, not a dependency that defines the internal architecture.

---

# 19. Local persistence

For MVP, all important application data should live locally.

At minimum:

```text
Studies
Chapters
Position tree
Repertoire decisions
Review states
Review history
Import metadata
Engine warnings
User preferences
```

The user should be able to close the application, reopen it later, and continue exactly where expected.

---

# 20. Future synchronization

Cloud synchronization is a major future capability.

The goal is not merely to synchronize the user's SRS intervals.

The application should eventually synchronize:

### SRS data

So the user's learned state follows them across:

- phone
- tablet
- web
- future platforms

### Studies

Studies themselves should also be synchronizable because PGNs are relatively small.

This means a future user experience could be:

```text
Phone
  ↕
Cloud
  ↕
Web
```

with both:

```text
Studies
+
Review state
```

available everywhere.

The local database remains the critical interactive layer.

Synchronization should happen asynchronously:

```text
local change
    ↓
UI updates immediately
    ↓
sync queue
    ↓
cloud
```

Never:

```text
local change
    ↓
wait for server
    ↓
UI updates
```

---

# 21. Future Lichess integration

The architecture should eventually support:

```text
Connect Lichess
       ↓
Authorize
       ↓
Fetch user's studies
       ↓
Select study
       ↓
Import / synchronize
       ↓
Review
```

The preferred mental model is:

> **Lichess is another source of repertoire, not another mode of the application.**

A user who connects Lichess should still experience exactly the same Review scene.

---

# 22. Studies as a secondary interface

Studies should exist, but they should not become a dominant product area.

The user may open the small study menu to answer:

> "What do I want to review right now?"

They should not have to navigate through a full study-management application.

A future study selector might look conceptually like:

```text
REVIEW

All

STUDIES
Sicilian
French
Tournament Prep
Coach Repertoire
```

The selected study simply changes the pool of review items.

The same principle applies to opening selection.

---

# 23. Opening-based review

The opening selector is a particularly useful future feature.

A user should be able to think:

> "Today I want to review my Sicilian."

rather than:

> "I need to open five different studies and find all my Sicilian chapters."

Therefore:

```text
OPENINGS

Sicilian
French
Caro-Kann
Queen's Gambit
King's Indian
...
```

selects positions across studies.

This is an important extension because **the player's chess repertoire is conceptually organized by openings, while the source files may be organized by studies.**

The application should allow both representations without forcing either to be primary.

---

# 24. Future feature directions

The following are intentionally possibilities rather than committed roadmap requirements:

### Lichess synchronization

Direct import and eventually ongoing synchronization of selected Lichess studies.

### Cross-device synchronization

Synchronize both studies and SRS state.

### Improved opening classification

Allow robust cross-study opening grouping.

### Better scheduling

Introduce more sophisticated SRS algorithms as evidence accumulates.

### Engine-assisted repertoire warnings

Expand the one-time import analysis while keeping it outside the Review loop.

### Notifications

Optional reminders that material is due.

### Advanced review controls

Potentially allow users to intentionally constrain the Review pool in useful ways.

The guiding principle remains:

> **Only add a feature if it makes remembering repertoire meaningfully better.**

---

# 25. Explicit non-goals

The MVP should deliberately avoid becoming:

- a tactics trainer
- an online chess server
- a social network
- a chess database
- an engine-analysis suite
- a community study platform
- a coaching platform
- a heavily gamified learning application
- a full study editor

These things may eventually coexist around the core, but they should not compete with Review.

---

# 26. Open-source inspiration and implementation references

The project should explicitly document the two primary sources of inspiration.

A repository-level documentation file should exist at:

```text
/docs/INSPIRATION.md
```

and the agent/developer documentation should link directly to both projects.

## ZackMurry/chessrs

**ChesSRS — Learn chess openings using spaced repetition**

GitHub:

https://github.com/ZackMurry/chessrs

This project is particularly useful for understanding:

- chess repertoire spaced repetition
- review scheduling
- training positions
- opening-learning workflows
- Lichess-related ideas

Its repository is currently public and describes itself as a system for learning chess openings with spaced repetition.

## ArneVogel/listudy

**Listudy — chess training application**

GitHub:

https://github.com/ArneVogel/listudy

This project is particularly useful for understanding:

- study structures
- training trees
- variation handling
- repertoire practice
- spaced-repetition-oriented chess training

The project should be treated as a direct implementation reference for solving domain problems, not as a codebase to copy wholesale.

## License awareness

Both projects are open source but use copyleft licenses.

ChesSRS is GPL-licensed and Listudy is AGPL-licensed.

Therefore the project's documentation should clearly distinguish:

> **Study the architecture and implementation ideas.  
> Reimplement independently unless deliberate license-compatible reuse is chosen.**

Agents working on chess-domain problems should be explicitly encouraged to inspect these repositories before inventing an entirely new solution.

---

# 27. Agent-facing documentation implication

The project should eventually contain an `AGENTS.md` that directs coding agents to the inspiration repositories when working on relevant features.

For example:

```text
## Chess-domain references

Before implementing or substantially redesigning chess repertoire,
PGN-tree, SRS, or training behaviour, inspect:

- https://github.com/ZackMurry/chessrs
- https://github.com/ArneVogel/listudy

These repositories are reference implementations and sources of
inspiration for domain behaviour and edge cases.

Do not blindly copy source code. Respect their licenses.
```

This is valuable because future agents can use the existing work as a source of proven domain patterns rather than repeatedly rediscovering how chess study trees and opening SRS systems work.

---

# 28. MVP success criteria

The MVP succeeds if a player can:

1. Open the application.
2. Import a real-world PGN.
3. Import PGNs containing multiple chapters and variations.
4. See the resulting study represented correctly.
5. Immediately begin Review.
6. Play repertoire moves naturally on the board.
7. Receive essentially instantaneous feedback.
8. Have already-learned portions automatically traversed when appropriate.
9. Encounter those positions again once they become due.
10. Close the app.
11. Return later and resume with correct SRS state.
12. Review all due material or quickly constrain Review to a specific study.

The most important qualitative test remains:

> **Does this feel like playing chess rather than operating a study application?**

---

# 29. Technical north star

The application should feel like:

```text
                    OPEN APP
                       ↓
                     REVIEW
                       ↓
                    THINK
                       ↓
                 ┌───────────┐
                 │ CHESSBOARD│
                 └─────┬─────┘
                       ↓
                      MOVE
                       ↓
               instant feedback
                       ↓
             learned moves skipped
                       ↓
                 next question
                       ↓
                    THINK
                       ↓
                     MOVE
                       ↓
                      ...
```

Everything outside this loop is secondary.

---

# 30. One-sentence product definition

> **A beautiful, instant, local-first chess repertoire trainer that turns your PGN studies into spaced-repetition practice for openings and middlegame positions.**

# 31. Guiding philosophy

**Import what you study.**  
**Recall it actively.**  
**Skip what you already know—until it's due again.**  
**Learn how to punish mistakes.**  
**Review when it matters.**
