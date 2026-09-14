# Lichess Mobile Cut Proposals

Status: **ACTIVE — Phase 1 F5+ staged cuts in progress.**

This document lists what should be removed from the Lichess Mobile fork to turn
it into the Chess Repertoire SRS foundation. Nothing here is executed silently;
cuts happen one subsystem per commit, with build + launch verification after
each step.

The guiding rule from the reset directive:

> The objective is not to preserve Lichess functionality for its own sake.
> The objective is to preserve its excellent foundation and remove unrelated
> product functionality.

---

## Execution status key

- `[ ]` — not started
- `[~]` — in progress
- `[x]` — completed (verified: analyze + tests + launch)
- `[!]` — BLOCKED (see notes)
- `[T]` — deferred to later phase (TRIM-LATER)

---

## 1. Lichess features that are clearly unnecessary (cut in Phase 1)

| # | Status | Area | Location(s) | Why cut | Dependency notes |
|---|---|---|---|---|---|
| C1 | `[ ]` | Firebase (core, crashlytics, messaging) | `pubspec.yaml`, `lib/src/binding.dart`, gradle plugins, `google-services.json` | Local-first app; no telemetry/cloud push | Isolated behind `LichessBinding` — replace with no-op test binding; remove gradle plugin IDs + google-services files |
| C2 | `[ ]` | Local notifications + home-screen widgets | `lib/src/model/notifications/`, `home_widget` usage in `app.dart`, `ios/LichessWidgets/`, `flutter_local_notifications` | Only make sense for online Lichess events | Remove service init in `app.dart`; iOS extension is native & separable; keep `flutter_native_splash` |
| C3 | `[ ]` | Authentication (OAuth, sign-in) | `lib/src/model/auth/`, `lib/src/view/auth/`, `flutter_appauth` | No accounts in our product (explicit non-goal) | Unblocks removal of C4–C8; `session`/`auth` providers in `model/auth` feed account, challenge, messages |
| C4 | `[ ]` | Online play (lobby, seek, create game, challenges) | `lib/src/view/play/`, `model/challenge/`, `model/lobby/` | Product is a trainer, not an online chess server | Depends on C3; `play` bottom tab removed from `tab_navigation.dart` |
| C5 | `[ ]` | Server game lifecycle (real-time games, correspondence) | `lib/src/view/game/` (online parts), `model/game/` (online lifecycle), `model/correspondence/` | No server games | Depends on C3; the *offline* game-frame widgets (`game_layout`, `board`, bottom bars, move list) must survive — they serve the Review scene |
| C6 | `[ ]` | Puzzles (all types: storm, streak, racer, theme training) | `lib/src/view/puzzle/`, `model/puzzle/` | Unrelated product (tactics trainer is an explicit non-goal) | Self-contained tab; removes `fl_chart` ACPL usage? no — acpl_chart stays in analysis; puzzle removal removes its own DB tables |
| C7 | `[ ]` | Watch (TV, tournaments, broadcasts, streamers) | `lib/src/view/watch/`, `model/tv/`, `model/tournament/`, `model/broadcast/` | Unrelated browsing/discovery | Self-contained tab |
| C8 | `[ ]` | Social (chat, messages, inbox, following/relations, player search) | `model/chat/`, `model/message/`, `model/relation/`, `view/chat/`, `view/message/`, `view/relation/` | Explicit non-goals | Depends on C3 |
| C9 | `[x]` | Learn section (coordinate training) | `lib/src/view/learn/`, `model/coordinate_training/` | Practice-with-server content; coordinate training is a separate product | See detailed plan below |
| C10 | `[ ]` | Blog, recap, announce | `model/blog/`, `model/recap/`, `model/announce/` + home carousels | Server content feeds | Remove home carousel widgets with them — home_tab_screen is heavily coupled; defer until home screen is redesigned |
| C11 | `[ ]` | Over-the-board play & pass-and-play clock | `lib/src/view/over_the_board/`, `model/over_the_board/`, `model/clock/` view parts | Different product (local two-player play) | **Owner decision**: chessrs/listudy don't have it; cut proposed, flag for review |
| C12 | `[ ]` | Offline computer play (play vs Stockfish) | `lib/src/view/offline_computer/`, `model/offline_computer/`, `multistockfish` | Not our product; engine only returns later as isolated advisory import checker | Depends on engine layer C13 |
| C13 | `[ ]` | Engine integration (Stockfish) | `model/engine/`, `view/engine/` | No engine in the review loop (explicit product rule) | Reintroduce *later*, isolated behind import pipeline, if advisory health-check is built |
| C14 | `[ ]` | Explorer (opening explorer) | `model/explorer/`, `view/explorer/` | Server-dependent; repertoire comes from PGN, not lichess DBs | Small |
| C15 | `[ ]` | Analysis screen (game analysis w/ evals) | `view/analysis/`, `model/analysis/` (parts) | Engine cockpit is a non-goal; *study screen shares its tree-view/PGN widgets* — extract those first | Depends on C13; the study chapter/PGN tree view code we want lives adjacent to analysis code — careful surgical cut |
| C16 | `[x]` | Board editor | `view/board_editor/`, `model/board_editor/` | Not needed for repertoire training | See detailed plan below |
| C17 | `[ ]` | WebSocket + online socket events | `network/socket.dart` | No real-time server features survive C4–C8 | After C3–C10 the socket has no consumers |
| C18 | `[ ]` | HTTP network layer (Lichess API repos) | `network/http.dart`, `model/*/*_repository.dart` (online) | Local-first: no Lichess server calls on any path | Keep `lichessUri` infra if we later add "import from Lichess study URL" (post-MVP horizon); otherwise strip to offline |

---

## 2. Useful during initial development — remove later (Phase 6)

| # | Item | Why keep for now |
|---|---|---|
| D1 | Study subsystem UI/controller (`view/study/`, `model/study/`) | Closest prior art to our review/study scene; adapt before deleting the online repository parts |
| D2 | `network/http.dart` offline/outage UI (`server_outage_display.dart`) | Provides graceful no-network behavior while we transition |
| D3 | Endgame/TV/etc. `more` tab screens | Removal of the `more` tab content can be batched with the settings reorganization |
| D4 | `deep_pick`, `fl_chart` | Used by surviving widgets (charts for review stats may be useful later — but only if justified by review UX, else cut with C15) |
| D5 | `over_the_board` clock widget (`widgets/clock.dart`) | Potentially useful board-time patterns; decide at Phase 6 |

---

## 3. Infrastructure unnecessary once local-first

| # | Item | Notes |
|---|---|---|
| I1 | Firebase gradle files, `fastlane`, `crowdin.yml`, widget scripts | Tooling for services removed above |
| I2 | `connectivity_plus` reconnect flows | No network path remains in core product |
| I3 | `app_links` deep links to lichess.org | No lichess URLs to handle |
| I4 | `share_plus`/social sharing | Depends on C-cuts; keep only if study export uses it (PGN export is ours, decide in Phase 2) |
| I5 | `dynamic_system_colors` / Material You | Lichess theme is already excellent; keep or cut per owner preference (default: keep — cheap, nice on Android) |

---

## 4. Large subsystems that would create needless maintenance

- **The whole `game/` online module**: game lifecycle, rematch, timers synced to server clocks. Keeping any of it invites continuous rebases against upstream lichess-mobile for features we never use.
- **Puzzle DB + puzzle services**: thousands of lines + DB migrations for a non-goal.
- **Correspondence gaming**: background service machinery with no purpose here.
- **Achievements/gamification** (if present in newer upstream): explicit product non-goal; never import.

---

## 5. What is explicitly NOT cut

- `dartchess` + `chessground` + piece/board assets — the board foundation
- `model/common/` (chess.dart, node.dart game tree, eval, id, uci, perf)
- `styles/`, `widgets/` reusable set, `db/` sqflite pattern, `model/settings/`
- l10n pipeline (we keep the machinery; content will shrink)
- `flutter_native_splash`, app shell, tab navigation skeleton (reduced to our tabs)
- GPL-3.0 LICENSE, COPYING.md, and attribution requirements — preserved verbatim, forever

---

## 6. Order of execution (each step gated: analyze → test → build → launch)

1. Strip coordinate_training + learn tab (C9) — **DONE**
2. Strip board_editor (C16) — **DONE**
3. Strip Firebase/notifications/widgets (C1, C2) — pure infrastructure
4. Strip auth (C3) — unlocks the social chain
5. Strip play/lobby/challenge/correspondence/game-online (C4, C5)
6. Strip puzzles/watch/blog/social (C6–C8, C10)
7. Strip engine/offline-computer/explorer/analysis (C12–C15)
8. Strip socket + HTTP repositories (C17, C18) — app becomes fully offline
9. Trim tabs to: **Review** (primary) + **Repertoire** + **Settings**
10. Rename/re-identity the application

Owner sign-off requested on: C11 (over-the-board), C15 (analysis screen), D4 (charts).

---

## 7. Detailed cut plans (executed cuts)

---

### C9 — Coordinate training + Learn tab

#### Why remove
Coordinate training (board square naming practice) is a standalone product with
no connection to repertoire building or SRS review. The Learn tab exists solely
to host it alongside "Lichess" practice materials (server-backed). Neither
belongs in ChessSRS.

#### Files — feature-specific (FEATURE-SPECIFIC, delete)

**model/coordinate_training/**
- `lib/src/model/coordinate_training/coordinate_training_controller.dart`
- `lib/src/model/coordinate_training/coordinate_training_controller.freezed.dart`
- `lib/src/model/coordinate_training/coordinate_training_preferences.dart`
- `lib/src/model/coordinate_training/coordinate_training_preferences.freezed.dart`
- `lib/src/model/coordinate_training/coordinate_training_preferences.g.dart`

**view/coordinate_training/**
- `lib/src/view/coordinate_training/coordinate_training_screen.dart`
- `lib/src/view/coordinate_training/coordinate_display.dart`

**view/learn/**
- `lib/src/view/learn/learn_tab_screen.dart`

**tests/**
- `test/view/coordinate_training/coordinate_training_screen_test.dart`

#### Files — shared/foundation (SHARED, edit only — do not delete)

- `lib/src/tab_scaffold.dart` — remove Learn tab case (index 2), reindex Watch→2, More→3
- `lib/src/tab_navigation.dart` — remove `BottomTab.learn` enum value + its 3 globals + interaction object

#### Shared dependencies that must remain
- `lib/src/model/settings/` — preferences infrastructure (used by all remaining features)

#### Risk: LOW
- coordinate_training: only referenced from `learn_tab_screen.dart`
- learn tab: only referenced from `tab_scaffold.dart` + `tab_navigation.dart`
- No cross-feature dependencies missed

#### Verification
- `fvm flutter analyze` — zero issues
- `fvm flutter test` — all tests pass (coordinate_training tests deleted; test count drops by 1 file)
- App launches, shows 4 bottom tabs (Home, Puzzles, Watch, More)
- No crash navigating to any remaining tab

---

### C16 — Board editor

#### Why remove
The board editor (FEN/position setup UI) is not needed for repertoire training.
Repertoire positions come from PGN import. The editor has no role in the SRS
review loop.

#### Files — feature-specific (FEATURE-SPECIFIC, delete)

**model/board_editor/**
- `lib/src/model/board_editor/board_editor_controller.dart`
- `lib/src/model/board_editor/board_editor_controller.freezed.dart`
- `lib/src/model/board_editor/position.dart`
- `lib/src/model/board_editor/position.freezed.dart`

**view/board_editor/**
- `lib/src/view/board_editor/board_editor_screen.dart`
- `lib/src/view/board_editor/board_editor_filters.dart`
- `lib/src/view/board_editor/board_editor_positions.dart`

**tests/**
- `test/view/board_editor/board_editor_screen_test.dart`

#### Files — shared/foundation (SHARED, edit only — do not delete)

- `lib/src/view/more/more_tab_screen.dart` — remove board_editor menu entry + import
- `lib/src/view/analysis/analysis_actions.dart` — remove `openBoardEditor()` helper + import
- `lib/src/app_links_service.dart` — remove deep-link route for board editor + import
- `test/app_links_service_test.dart` — remove board_editor import + related test cases

#### Shared dependencies that must remain
- `lib/src/view/more/more_tab_screen.dart` itself (keeps all other More menu items)
- `lib/src/view/analysis/` (analysis screen retained as TRIM-LATER)
- `lib/src/app_links_service.dart` (deep-link infra retained for other links)

#### Risk: LOW-MEDIUM
- 3 edit sites in distinct subsystems (more tab, analysis, app_links)
- analysis_actions.dart must lose `openBoardEditor()` without breaking other actions
- app_links_service test needs matching edit

#### Verification
- `fvm flutter analyze` — zero issues
- `fvm flutter test` — all tests pass (board_editor tests deleted; app_links test updated)
- App launches, More tab has no Board Editor entry
- No crash navigating to any screen
