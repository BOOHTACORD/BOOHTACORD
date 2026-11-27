# Issue 785 microphone lifecycle implementation plan

> Execute inline, task by task; physical acceptance remains a separate gate.

**Goal:** Prevent a superseded Android microphone-service start from reviving
stopped state or stopping a newer, explicitly requested microphone session.

**Architecture:** Keep the existing MethodChannel and native Android admission
policy. Fence every asynchronous start result by the current session generation,
invalidate that generation on native service loss, and coalesce concurrent starts.
No automatic background restart, new Room, or change to mute/permission intent.

**Tech Stack:** Flutter/Dart, Android microphone FGS, existing paired LiveKit QA.

## Operating brief

- workflow_class=split_first; task_size=large; structure_mode=structure_no_rg.
- Packet: Android microphone-service asynchronous lifecycle; other #785 work
  (iOS, physical routing, full mobile-Web matrix) is explicitly separate.
- Backlog owner: T-022; read dependencies T-006/T-020 and their existing checks.
- Route: `clients/flutter/lib/src/features/voice/background_microphone/session.dart`.
- Exact native edge: `VoiceMicrophonePlugin.kt` invokes `start`/`stop` and reports
  `stopped`; `admission.dart` converts unexpected loss to muted listener intent.
- Preserve: explicit leave/dispose cancellation, foreground admission, no native
  calls on desktop, fail-closed promotion, no background auto-unmute/restart.
- Limits: 120 lines/file, at most 16 direct tests/production files per leaf.
- Baseline: current master `0173e6a82b43497c7a7ba79a967c83a2aa429b30`;
  run the existing session/controller tests before introducing regressions.
- Stop condition: focused regression and existing tests pass; isolated native
  paired run and CI recorded accurately; issue updated without closing unrun gates.
- Open gate: no physical Android/iPhone currently visible; RTP is not audibility.

## Task 1: Reproduce lifecycle races

- [x] Preserve baseline results in `.out/baseline-microphone.log`.
- [x] Add `clients/flutter/test/features/background_microphone/start_races_test.dart`:
  concurrent callers share a native start; stale failure cannot stop a replacement;
  native stop invalidates a pending success. Use deferred futures and the real
  MethodChannel codec rather than source-text assertions.
- [x] Run the new tests against unchanged production code and retain failures.

## Task 2: Fence start completion

- [x] Update only `background_microphone/session.dart`: share pending start,
  invalidate on native stop, ignore superseded failures, retain bounded timeout.
- [x] Run `flutter test test/features/background_microphone` and analyze exact files.
- [x] Register the new behavior test and parity decisions in
  `tools/qa/local_features/features.json`; regenerate product-map if required.

## Task 3: Native acceptance and delivery

- [x] Use the dedicated Android QA emulator and disposable Go/PostgreSQL/LiveKit
  stack with an independent browser receiver; run existing background/resume and
  external-service-stop/retry cases. Capture counters and inspect native screenshots.
- [ ] Run registered local-feature/native checks and Contracts; retain any unrelated
  blocked platform gates honestly. Add scoped evidence with source hashes.
- [ ] Run preflight and explicit review before commit; push PR, inspect exact-head
  CI and review, and merge only after its required gates pass.
- [ ] Update #785 with results and remaining physical/iOS/release gates.
