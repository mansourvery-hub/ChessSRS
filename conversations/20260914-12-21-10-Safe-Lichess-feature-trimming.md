# Session: Safe Lichess feature trimming for ChessSRS

**Created:** 2026-09-14 12:21:10

---

## Conversation

### 🤖 Assistant
*2026-09-14 12:36:03*

# Task: Safely trim unnecessary Lichess Mobile features from ChessSRS

Repository:
https://github.com/mansourvery-hub/ChessSRS

IMPORTANT CONTEXT

ChessSRS is now based on a fork of Lichess Mobile.

The Lichess codebase is the new technical foundation.

We want to remove Lichess features that are irrelevant to a local-first chess repertoire SRS app.

However:

THIS IS A SAFE DELETION TASK, NOT A REWRITE.

The application is already building and launching successfully.

Your highest priority is:

KEEP THE APP WORKING.

Do not optimize for maximum deletion.

Do not perform a giant cleanup.

Do not delete large directories because they "look unrelated."

Do not combine multiple risky removals into one commit.

---

# 1. ESTABLISH A BASELINE FIRST

Before touching anything:

- inspect the current repository state;
- run the normal verification command(s);
- run static analysis;
- run the test suite;
- launch the actual Linux application;
- verify that the application reaches its normal startup screen;
- record the baseline result.

If any baseline check fails, STOP.

Do not begin feature removal until the baseline is known to be healthy.

Create:

`docs/LITCHESS_TRIM_BASELINE.md`

containing:

- commit SHA
- verification result
- test result
- launch result
- any known pre-existing warnings/issues

---

# 2. MAP BEFORE DELETING

Before deleting anything, build a dependency map of the Lichess features you propose removing.

For every candidate feature, determine:

- entry points
- routes
- widgets/screens
- providers/controllers/state
- services
- models
- assets
- localization strings
- platform-specific code
- dependencies used exclusively by the feature
- shared dependencies used by multiple features
- initialization code
- test coverage

Classify each file as:

`FEATURE-SPECIFIC`
`SHARED`
`FOUNDATION`
`UNKNOWN`

NEVER delete `SHARED`, `FOUNDATION`, or `UNKNOWN` code merely because it appears associated with a feature.

---

# 3. PRODUCE THE CUT PLAN BEFORE EXECUTION

Create or update:

`CUT_PROPOSALS.md`

For every proposed removal use:

### Feature
Name

### Why remove it
Why it has no place in ChessSRS.

### Files/subsystems involved
Concrete paths.

### Shared dependencies
Anything that must remain.

### Risk
LOW / MEDIUM / HIGH

### Removal order
Exact sequence.

### Verification
What must still work afterward.

Do not execute HIGH-risk removals yet.

---

# 4. REMOVE ONE FEATURE AT A TIME

For each approved/low-risk feature:

1. isolate the feature;
2. remove its route/entry point;
3. remove its UI;
4. remove feature-specific state/controllers;
5. remove feature-specific services;
6. remove feature-specific assets/localizations;
7. remove now-unused dependencies/imports;
8. update tests;
9. run formatting;
10. run static analysis;
11. run tests;
12. run `./verify`;
13. launch the actual application;
14. verify startup manually.

Only after all checks pass may you move to the next feature.

ONE FEATURE = ONE LOGICAL CHANGE.

Do not batch ten deletions together.

---

# 5. GIT SAFETY

Before the first deletion:

Create a safety tag:

`trim-baseline`

After every successful removal, make a commit.

Use descriptive commits such as:

`trim: remove Lichess tournaments`

`trim: remove Lichess social navigation`

Never leave a huge uncommitted destructive refactor in the working tree.

If a removal breaks the application and the cause is unclear:

STOP.

Revert that removal.

Do not keep stacking fixes on top of a broken deletion.

---

# 6. DEFINITION OF "REMOVED"

A feature is considered removed only when:

- the user cannot navigate to it;
- its feature-specific UI is gone;
- its feature-specific state/services are gone;
- its feature-specific assets are gone;
- its feature-specific dependencies are gone where safe;
- no dead routes remain;
- no startup initialization remains solely for that feature;
- tests and analysis still pass;
- the application still launches.

Do not pursue zero references at any cost.

Some Lichess infrastructure may remain because ChessSRS needs it.

---

# 7. PRESERVE THE LICHESS FOUNDATION

Do NOT remove or replace these merely because they originated in Lichess:

- board/chessground infrastructure
- navigation foundations
- theme system
- reusable UI primitives
- responsive layout infrastructure
- platform abstractions
- useful settings/preferences infrastructure
- localization infrastructure that remains useful
- app lifecycle/bootstrap infrastructure
- shared networking abstractions until proven unnecessary
- common models/utilities used by retained functionality

Remember:

We are trimming the Lichess PRODUCT.

We are not destroying the Lichess TECHNICAL FOUNDATION.

---

# 8. LIKELY CUT CATEGORIES

Investigate these first, but DO NOT assume they can simply be deleted:

- tournaments
- challenges
- social/friends/following
- chat
- teams
- broadcasts
- messaging
- server-oriented game flows
- Lichess account/authentication flows
- unrelated online discovery/browsing
- notifications tied exclusively to Lichess social/server features

For each one, trace dependencies before removal.

---

# 9. IMPORTANT: KEEP THINGS THAT MAY BECOME USEFUL

Do NOT remove functionality merely because it isn't used by today's beta.

Some infrastructure may be valuable for:

- study navigation
- board interaction
- PGN viewing
- local import
- future analysis
- settings
- review flows

When uncertain:

KEEP IT.

Record it as:

`TRIM-LATER`

rather than deleting it.

---

# 10. DO NOT IMPLEMENT OUR PRODUCT YET

This phase is ONLY about safely trimming the Lichess foundation.

Do not start implementing:

- repertoire domain
- SRS
- PGN import
- study trees
- review engine
- persistence

Those come afterward.

The goal of this phase is:

A smaller, cleaner, still-working Lichess-derived application.

---

# 11. STOP CONDITIONS

Immediately stop and report instead of improvising when:

- deleting a feature touches many shared subsystems;
- removing a dependency causes broad compilation failures;
- startup/bootstrap code becomes unclear;
- a feature is deeply coupled to retained Lichess infrastructure;
- you cannot determine whether something is feature-specific or foundational;
- a deletion causes runtime instability;
- verification passes but the actual app no longer launches correctly.

Do not "fix forward" through an architectural problem.

---

# 12. RUNTIME VALIDATION IS MANDATORY

Passing tests is NOT sufficient.

For every deletion milestone:

    format
       ↓
    analyze
       ↓
    tests
       ↓
    ./verify
       ↓
    launch real application
       ↓
    manually inspect startup/navigation
       ↓
    commit

The prior project demonstrated that automated verification can pass while the actual application is broken or visually wrong.

Do not repeat that failure mode.

---

# 13. FIRST MILESTONE

Do NOT start deleting immediately.

First complete:

### M0 — Trim inventory

Deliver:

`CUT_PROPOSALS.md`

and:

`docs/LITCHESS_TRIM_BASELINE.md`

Then identify the FIRST lowest-risk feature that can be removed independently.

Remove ONLY that feature.

Verify everything.

Commit it.

Then continue with the next lowest-risk isolated feature.

---

# SUCCESS CRITERION

The final result of this task is NOT:

"we deleted the most code possible."

It is:

"we removed unnecessary Lichess product functionality while preserving a stable, reusable Lichess foundation for ChessSRS."

When in doubt:

DELETE LESS.
VERIFY MORE.

### 🤖 Assistant
*2026-09-14 12:36:03*

*[step-start part]*

#### 🔧 Tool: todowrite
**Status:** completed
**Title:** 4 todos

**Input:**
```json
{
  "todos": [
    {
      "priority": "high",
      "content": "Inspect repo state and run baseline verification, tests, and launch app",
      "status": "in_progress"
    },
    {
      "priority": "high",
      "status": "pending",
      "content": "Create docs/LITCHESS_TRIM_BASELINE.md and tag trim-baseline"
    },
    {
      "content": "Map features and update/create CUT_PROPOSALS.md",
      "status": "pending",
      "priority": "high"
    },
    {
      "priority": "high",
      "status": "pending",
      "content": "Execute feature removals one by one with full verification and atomic commits"
    }
  ]
}
```

**Output:**
```
[
  {
    "content": "Inspect repo state and run baseline verification, tests, and launch app",
    "status": "in_progress",
    "priority": "high"
  },
  {
    "content": "Create docs/LITCHESS_TRIM_BASELINE.md and tag trim-baseline",
    "status": "pending",
    "priority": "high"
  },
  {
    "content": "Map features and update/create CUT_PROPOSALS.md",
    "status": "pending",
    "priority": "high"
  },
  {
    "content": "Execute feature removals one by one with full verification and atomic commits",
    "status": "pending",
    "priority": "high"
  }
]
```

*[step-finish part]*

### 🤖 Assistant
*2026-09-14 12:36:03*

*[step-start part]*

I will inspect

*[step-finish part]*

### 🤖 Assistant
*2026-09-14 12:36:03*

### 🤖 Assistant
*2026-09-14 12:36:03*

continue

### 🤖 Assistant
*2026-09-14 12:36:03*
