# Lichess Mobile Cut Proposals

Status: **ACTIVE — Phase 1 F5+ staged cuts in progress.**

This document is the authoritative record of what is removed, what is kept,
and why. Update it before executing any cut. Future agents: read this entire
file before touching anything.

The guiding rule:

> Trim the Lichess **product**. Preserve the Lichess **technical foundation**.
> When uncertain: keep it. Delete less, verify more.

---

## Execution status key

- `[ ]` not started
- `[~]` in progress
- `[x]` DONE — verified (analyze 0 + all tests pass + app launches)
- `[K]` KEEP — owner decision: do not remove
- `[G]` GREY — owner undecided; leave untouched until explicit approval
- `[T]` TRIM-LATER — defer to Phase 6 refinement

---

## Owner decisions (recorded 2026-09-14)

These are the authoritative decisions from the owner. Do not override them.

| # | Decision | Rationale |
|---|---|---|
| C1 Firebase | `[G]` GREY | Undecided — leave untouched |
| C2 Notifications | `[G]` GREY | May be needed for SRS review reminders (like Anki) — leave untouched |
| C3 Auth/login | `[K]` KEEP | Login is optional but enables importing Lichess/chess.com studies; app is 100% functional offline without it |
| C4 Online play | `[ ]` REMOVE | Approved |
| C5 Server games | `[ ]` REMOVE | Approved — preserve offline game-frame widgets (board, move list) |
| C6 Puzzles tab | `[ ]` REMOVE | Approved |
| C7 Watch tab | `[ ]` REMOVE | Approved |
| C8 Social | `[ ]` REMOVE | Approved (depends on C3 staying; see notes below) |
| C9 Learn tab + coord training | `[x]` DONE | Removed 2026-09-14 |
| C10 Blog/recap/announce | `[ ]` REMOVE | Approved |
| C11 Over-the-board game | `[ ]` REMOVE | Approved — OTB = local 2-player pass-and-play; not our product |
| C11 Chess clock tool | `[K]` KEEP | Clock tool is a standalone utility; distinct from OTB game; keep |
| C12 Offline computer play | `[ ]` REMOVE | Approved (follows from C13) |
| C13 Engine (Stockfish) | `[G]` GREY | May be useful as optional import advisor — undecided |
| C14 Opening explorer | `[K]` KEEP | Owner decision |
| C15 Analysis screen | `[G]` GREY | Undecided — shares widgets with study; leave untouched |
| C16 Board editor | `[K]` KEEP | Owner decision |
| C17 WebSocket | `[ ]` REMOVE | Follows from C4–C10 |
| C18 HTTP repos | `[ ]` REMOVE | Follows from C4–C10; keep auth HTTP for C3 |
| UI-A Donate / patron links | `[ ]` REMOVE | Lichess branding; not our product |
| UI-B "About Lichess" in More tab | `[ ]` REMOVE | Replace with ChessSRS about if needed later |
| UI-C "Lichess is a free…" message (LichessMessage widget) | `[ ]` REMOVE | Lichess brand copy |
| UI-D "Welcome to the Lichess app" card | `[ ]` REMOVE | Lichess brand copy |
| UI-E "Not all features available" text | `[ ]` REMOVE | Part of Lichess welcome card |

**C8 Social note**: Friends list, inbox, player search, and relations all
depend on C3 (auth) staying. Since C3 is kept, these screens remain loadable
for logged-in users. However they are Lichess social features not relevant to
ChessSRS. Remove the navigation entry points from More tab; the underlying
model code can stay until a later cleanup pass when the HTTP layer is trimmed.

---

## Safe execution order

Each step is ONE logical change, ONE commit. Gate: `fvm flutter analyze` (0
issues) + `fvm flutter test` (all pass) + `fvm flutter run -d linux` (app
launches, manual spot-check) before proceeding to the next step.

**NEVER batch multiple steps into one commit.**

```
Step 1  [x]  C9  — Learn tab + coordinate training                  DONE
Step 2  [x]  UI  — Lichess branding strings from home + more screens DONE
Step 3  [ ]  C7  — Watch tab (TV / tournaments / broadcasts)
Step 4  [ ]  C6  — Puzzles tab
Step 5  [ ]  C11 — Over-the-board game (NOT clock tool)
Step 6  [ ]  C10 — Blog / recap / announce (home carousels + model)
Step 7  [ ]  C4  — Online play: lobby / seek / challenges
              (depends on: home_tab_screen already cleaned of play widgets)
Step 8  [ ]  C5  — Server game lifecycle + correspondence
              (depends on: C4 done; preserve game-frame board widgets)
Step 9  [ ]  C8  — Social navigation entries from More tab
              (model code stays for now; just remove entry points)
Step 10 [ ]  C17 — WebSocket (no consumers left after C4–C8)
Step 11 [ ]  C18 — HTTP repositories (online repos only; keep auth HTTP)
Step 12 [ ]  Tab reduction: trim to Home + Settings (+ future Review tab)
              (after C4–C8 the remaining tabs are Home and More/Settings only)
```

Steps beyond 12 (C12 offline computer, C13 engine) are blocked on owner
GREY decisions and are not started until explicit approval.

---

## Detailed cut plans

---

### Step 2 — Lichess branding strings (UI-A through UI-E)

**Why**: These are Lichess product strings that appear in the ChessSRS UI.
They confuse users and misrepresent the product.

**What to remove** (surgical edits, no file deletions):

- `lib/src/view/home/home_tab_screen.dart`
  - Remove `_WelcomeMessageCard` widget render (the "Welcome to the Lichess
    app / not all features available" card shown on first launch).
    The `_WelcomeMessageCard` class and its state can be deleted.
  - Remove the donate (`https://lichess.org/patron`) `FilledButton.tonal`
    block in the welcome screen branch.
  - Remove the "About Lichess" (`https://lichess.org/about`) `FilledButton.tonal`
    block in the welcome screen branch.
  - Remove `_LichessMessageBanner` (the unread Lichess server message banner)
    — this is a Lichess inbox feature that will be removed with C8 anyway;
    safe to remove from the home screen display now.
  - Remove `LichessMessage` widget usage from the welcome branch.
  - Keep `unreadMessagesProvider` watch for now (C8 will clean it up).

- `lib/src/view/more/more_tab_screen.dart`
  - Remove the Android-only `ListSection` containing patron/donate tile and
    "About" tile (lines 184–205).
  - Remove `LichessMessage` widget at the bottom of the More tab list.
  - Keep `AboutScreen` import removal if the tile is the only caller — check
    before deleting.

**Shared dependencies that must remain**: `LichessMessage` widget class in
`widgets/misc.dart` — other callers may exist; remove references not the
widget itself. `AboutScreen` — check if any other caller exists before
deciding whether to delete the screen.

**Risk**: LOW — pure UI text/widget removal, no state or routing changes.

**Tests to update**: `test/app_test.dart` — if it asserts the welcome message
text, update accordingly.

---

### Step 3 — C7: Watch tab

**Why**: TV, tournaments, broadcasts, and streamers are Lichess server content
with no relevance to repertoire training.

**Files — FEATURE-SPECIFIC (delete)**:
- `lib/src/view/watch/` (entire directory)
- `lib/src/model/tv/` (entire directory)
- `lib/src/model/tournament/` (entire directory)
- `lib/src/model/broadcast/` (entire directory)
- `test/view/watch/` (if exists)
- `test/model/tv/`, `test/model/tournament/`, `test/model/broadcast/` (if exist)

**Files — SHARED (edit only)**:
- `lib/src/tab_scaffold.dart` — remove Watch case, reindex More tab
- `lib/src/tab_navigation.dart` — remove `BottomTab.watch` + its globals
- `lib/src/view/home/home_tab_screen.dart` — remove
  `FeaturedTournamentsWidget`, `featuredTournamentsProvider` usage,
  `tournament_list_screen` import, `tournament_providers` import
- `test/app_test.dart` — remove 'Watch' bottom-nav assertion

**Shared dependencies to check before deleting**:
- `model/broadcast/broadcast_preferences.dart` — referenced in `app.dart`
  `_screenSizeBasedInitialization`; remove that call too.
- `model/broadcast/broadcast_service.dart` — started in `app.dart`; remove.
- Tournament model types used in home screen — remove those usages first.

**Risk**: MEDIUM — home screen references tournament widgets; must clean those
before deleting model files.

---

### Step 4 — C6: Puzzles tab

**Why**: Tactics training is an explicit non-goal of ChessSRS.

**Files — FEATURE-SPECIFIC (delete)**:
- `lib/src/view/puzzle/` (entire directory)
- `lib/src/model/puzzle/` (entire directory)
- `test/view/puzzle/` (if exists)
- `test/model/puzzle/` (if exists)

**Files — SHARED (edit only)**:
- `lib/src/tab_scaffold.dart` — remove Puzzles case, reindex remaining tabs
- `lib/src/tab_navigation.dart` — remove `BottomTab.puzzles` + its globals
- `lib/src/view/home/home_tab_screen.dart` — remove any puzzle references
  (home_widgets puzzle entry if present)
- `lib/src/view/more/more_tab_screen.dart` — remove puzzle entry if present
- `lib/src/app_links_service.dart` — remove puzzle deep-link handling
- `test/app_test.dart` — remove 'Puzzles' bottom-nav assertion
- `pubspec.yaml` — check if any puzzle-only packages can be removed

**Risk**: MEDIUM — puzzle tab is a whole tab; check home screen home_widgets
enum for puzzle references.

---

### Step 5 — C11: Over-the-board game (NOT clock tool)

**Why**: Pass-and-play local two-player chess is a different product. The
chess clock tool is a separate, standalone utility and is **kept**.

**Files — FEATURE-SPECIFIC (delete)**:
- `lib/src/view/over_the_board/` (entire directory — 2 files)
- `lib/src/model/over_the_board/` (entire directory)
- `lib/src/model/game/over_the_board_game.dart` + generated files
  — **only if** these are not shared with the game/ online module; verify
  before deleting.
- `test/view/over_the_board/` and `test/model/over_the_board/` (if exist)

**Files — SHARED (edit only)**:
- `lib/src/view/play/play_menu.dart` — remove OTB entry + import
- `lib/src/view/analysis/analysis_actions.dart` — remove
  `OverTheBoardScreen.buildRoute()` call + import
- `lib/src/view/board_editor/board_editor_screen.dart` — remove OTB
  "play from position" action + import (board editor is kept)

**Clock model stays** (`lib/src/model/clock/` — kept; used by clock tool).

**Risk**: LOW-MEDIUM — 3 edit sites; model isolation straightforward.

---

### Step 6 — C10: Blog / recap / announce

**Why**: Server-pushed content feeds with no relevance to local-first SRS.

**Files — FEATURE-SPECIFIC (delete)**:
- `lib/src/model/blog/` (entire directory — 3 files)
- `lib/src/model/recap/recap_service.dart`
- `lib/src/model/announce/announce_service.dart`
- `lib/src/view/home/blog_carousel.dart`

**Files — SHARED (edit only)**:
- `lib/src/app.dart` — remove `recapServiceProvider.start()` and
  `announceServiceProvider.start()` from `initState`; remove their imports
- `lib/src/view/home/home_tab_screen.dart` — remove `blogCarouselProvider`
  watch, `_BlogCarouselWidget` usage, `HomeEditableWidget.blogCarousel`
  usage, `blog_carousel.dart` import, `blog.dart` + `blog_repository.dart`
  imports
- `lib/src/model/account/home_widgets.dart` — remove `blogCarousel` from
  `HomeEditableWidget` enum and its references

**Risk**: MEDIUM — home_tab_screen has multiple blog reference sites; methodical
line-by-line removal required.

---

### Steps 7–9 — C4 / C5 / C8: Online play, server games, social entries

These are larger cuts with more cross-cutting references. Detailed plans will
be written immediately before execution. Key constraint: **C3 (auth) stays**,
so the auth model and HTTP client infrastructure is preserved.

High-level scope:
- C4: Remove `view/play/` lobby/seek UI; `model/challenge/`; `model/lobby/`
- C5: Remove online game lifecycle from `view/game/` and `model/game/`;
  remove `model/correspondence/`; preserve game-frame board widgets
- C8: Remove navigation entry points to friends/inbox/players from More tab;
  model/social code stays for now

---

### Steps 10–11 — C17 / C18: WebSocket + HTTP repositories

Execute only after C4–C9 are done and confirmed to have no remaining socket
or HTTP consumers outside auth and study-import paths.

---

## What is explicitly NOT cut

- `dartchess` + `chessground` + piece/board assets
- `model/common/` (chess.dart, node.dart, eval, id, uci, perf, etc.)
- `styles/`, `widgets/` reusable set, `db/` sqflite, `model/settings/`
- l10n pipeline
- `model/auth/` (C3 kept — optional login for study import)
- `view/study/`, `model/study/` (D1 — closest to our review scene)
- `view/analysis/`, `model/analysis/` (C15 grey — shared with study)
- `view/board_editor/`, `model/board_editor/` (C16 kept)
- `model/explorer/`, `view/explorer/` (C14 kept)
- `view/clock/`, `model/clock/` (clock tool kept)
- `network/http.dart` base infra (needed for auth + study import)
- GPL-3.0 LICENSE, COPYING.md, copyright notices — preserved forever

---

## Completed cuts

| Step | Feature | Commit | Date | Tests before → after |
|---|---|---|---|---|
| 1 / C9 | Learn tab + coordinate training | `f74627873` | 2026-09-14 | 1570 → 1564 |
| 2 / UI | Lichess branding (donate, about, LichessMessage, welcome card) | `1af79eab3` | 2026-09-14 | 1564 → 1564 |
