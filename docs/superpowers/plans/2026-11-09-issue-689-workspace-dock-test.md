# Issue 689 Workspace Dock Test Refactor Implementation Plan

> **For agentic workers:** Preserve existing behavior and use the repository's Slavik Gym workflow.

**Goal:** Reduce the oversized voice-dock widget test without changing its assertions, state transitions or registration.

**Architecture:** Extract contiguous, responsibility-focused portions of the existing test callback into private Dart part functions in the same test library. Keep setup, exact call order and cleanup in the original callback; preserve the original statements in each helper.

**Tech Stack:** Flutter widget tests, Dart parts and analyzer.

---

### Task 1: Preserve the existing behavior

**Files:**
- Read: `clients/flutter/test/workspace_screen_test.dart`
- Create a disposable draft in `clients/flutter/test/issue689_workspace_dock_draft/`
- Add focused helper parts under `workspace_screen_parts/voice_dock/` in the draft.

- [x] Run `flutter test test/workspace_screen_test.dart`; require all 115 existing test cases to pass with no skips.
- [x] Extract connected presentation, microphone modes, sound preferences, screen/join controls, deafen, reconnect, and leaving/error assertions into separate private helpers. Verify every extracted statement is present unchanged and called in the original order.
- [x] Run the draft's named voice-dock test and the full 115-test file, then analyze the draft and check each new part is at most 120 physical lines.

### Task 2: Apply the focused change

**Files:**
- Modify: `clients/flutter/test/workspace_screen_test.dart`
- Create: `clients/flutter/test/workspace_screen_parts/voice_dock/*.dart`

- [x] Save the original working-tree file outside the repository, apply the validated parts and rewrite only their relative paths.
- [x] Run the full original test path, compare all 115 test names and ordering with baseline, and analyze both the original path and its new parts.
- [x] Retain the disposable draft outside test discovery. Record the result and explicitly keep the remaining oversized workspace test as unfinished work.
