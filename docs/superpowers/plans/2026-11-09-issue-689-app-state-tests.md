# Issue 689 App State Test Refactor Implementation Plan

> **For agentic workers:** Apply the repository's Slavik Gym workflow; preserve the existing test registrations and behavior before changing the source.

**Goal:** Split the modified oversized Flutter app-state test into focused, size-bounded parts without changing any of its 53 test cases or fake API behavior.

**Architecture:** Keep a small test entrypoint with the original binding and preference initialization. Register the original tests in their original order from private Dart parts grouped by behavior. Split the existing fake into a state-bearing base and behavior-specific mixins within the same Dart library, preserving each original method body.

**Tech Stack:** Dart analyzer AST, Flutter test, Windows Flutter SDK.

---

### Task 1: Baseline and draft

**Files:**
- Read: `clients/flutter/test/app_state_test.dart`
- Generate a disposable draft under `clients/flutter/.out/issue689-app-state-draft/`
- Use `D:/Codex/toolchains/issue689-shims/dart-ast-draft/export_spans.dart` to extract AST offsets.

- [x] Run `flutter test test/app_state_test.dart`; require 53 passes, no skips.
- [x] Generate part files for session, profile, voice, audio, text and direct-message test families. Keep registration order and every test body byte-for-byte unchanged.
- [x] Split `_FakeApi` into a base and focused mixins, preserving all member bodies and constructor defaults. Compare every extracted AST slice to the original source before writing the draft.
- [x] Run `flutter test .out/issue689-app-state-draft/app_state_test.dart`; require the same 53 test names and no skips. Run `flutter analyze` on the draft and check each generated file is at most 120 physical lines. The analysis check passed after placing the draft under the normal test tree; outside it the analyzer produced test-only API warnings.

### Task 2: Apply and verify

**Files:**
- Modify: `clients/flutter/test/app_state_test.dart`
- Create: focused Dart parts under `clients/flutter/test/app_state_parts/`

- [x] Apply the validated draft with relative `part` and import paths adjusted for `test/`; preserve the original source separately until verification is complete.
- [x] Run `flutter test test/app_state_test.dart` and compare the 53 test names to the baseline; require no skips.
- [x] Run `flutter analyze` on the entrypoint and parts; inspect the diff and file sizes. Record any blocked check rather than marking it passed.
- [x] Keep the separate `workspace_screen_test.dart` refactor as a later packet; do not change it in this packet.
