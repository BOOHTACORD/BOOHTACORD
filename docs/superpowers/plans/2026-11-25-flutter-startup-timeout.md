# Flutter startup timeout isolation implementation plan

> **For agentic workers:** Use superpowers:executing-plans to implement this plan task by task in this chat.

**Goal:** Prevent an expired startup attempt from preparing or replacing an account and allow a fresh manual retry.

**Architecture:** Preserve the existing 20-second deadline and retry UI. Close the expired session generation before publishing its error so existing captured tickets reject late work. A retry opens a fresh generation; it does not delete saved credentials.

**Tech Stack:** Flutter/Dart, flutter_test, existing native QA and GitHub CI.

## Task 1: Startup boundary regression

Files: `clients/flutter/test/session_lifecycle/startup_timeout_test.dart`, `fake_effects.dart`, `clients/flutter/lib/src/features/session/lifecycle/restore.dart`.

- [x] Add focused failing cases for API/platform/session/preparation stalls, late completion and successful retry.
- [x] Run the cases on the unchanged implementation and preserve the failure.
- [x] Invalidate only the expired attempt; preserve ordinary errors, logout, server changes and successful restoration.
- [x] Run session, app-state and HTTP boundary tests plus analyzer.

## Task 2: Acceptance and merge

Files: `tools/qa/local_features/features.json`, `backlog/tasks.yaml`, `backlog/FRONTEND_TODO.md`, scoped `evidence/qa` report and applicable native QA target.

- [x] Register tests and shared-client parity; add a bounded leaf under T-050/T-051 without closing physical macOS Keychain acceptance.
- [x] Exercise the retry screen and real API restoration on available owned native targets; inspect captures. Record unavailable targets honestly.
- [x] Run native contracts and preflight, inspect the complete diff and file sizes.
Merge gate: open a PR, require successful exact-head CI, resolve failures and record merge/tracking in the PR timeline. This document does not pre-attest a future merge.

## Preservation and limits

No auth policy, API contract, cookie deletion, microphone capture or media change. OS storage requests are not force-cancelled. The stale-result fence is the acceptance target. A native mocked-storage test does not establish macOS Keychain prompt behavior.
