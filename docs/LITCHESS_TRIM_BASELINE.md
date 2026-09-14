# Lichess Trim Baseline

**Date:** Mon Sep 14 2026  
**Commit SHA:** `fcbaec595d1ebfd3dc327307ab6e44b6784b29db`  
**Git Tag:** `trim-baseline`  

---

## 1. Static Analysis Result
- Command: `fvm flutter analyze`
- Result: **Passed (Clean)**
- Output:
  ```text
  Analyzing Chess Repertoire SRS...
  No issues found! (ran in 6.3s)
  ```

---

## 2. Automated Test Suite Result
- Command: `fvm flutter test`
- Result: **Passed (All 1,570 tests passed)**
- Note on execution time: The full suite takes ~2 minutes 54 seconds.
- Output:
  ```text
  02:54 +1570: All tests passed!
  ```

---

## 3. Launch Result (Linux Desktop)
- Command: `fvm flutter build linux --debug` & executable launch check
- Binary built at: `build/linux/x64/debug/bundle/chess_srs`
- Launch behavior:
  - Startup cleanly initializes Impeller OpenGL/ES backend.
  - Reaches normal startup screen (Home screen with welcome/recent games/quick pairing, navigation shell).
  - Normal anonymous HTTP requests initiated to lichess API (carousel/featured tournament).
  - No crash, abort, or freeze on launch.

---

## 4. Known Pre-existing Warnings / Issues
- In test output:
  - Several unit tests log handled exceptions (e.g. `ClientException: Request to /api/... failed with status 404/500`, `FormatException: Unexpected end of input` for mock network outage tests). These are expected test cases testing error-handling logic.
- GDK/X11 cursor theme message:
  - `Gdk-Message: ... Unable to load from the cursor theme` (benign host environment warning).
- Untracked files:
  - Conversation logs under `conversations/` (git ignored / user conversation logs).

---

## 5. Ready for Trimming
Baseline verified healthy and stable. Feature trimming will proceed feature-by-feature following `CUT_PROPOSALS.md` with complete verification loop per cut.
