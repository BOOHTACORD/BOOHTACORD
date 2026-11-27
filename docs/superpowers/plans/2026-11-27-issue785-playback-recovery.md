# Issue 785 playback and recovery implementation plan

> **For agentic workers:** Execute inline with the executing-plans workflow,
> one bounded packet at a time. Hardware gates remain separate.

**Goal:** Preserve an explicitly started Android listening session across late
foreground-service replies, and verify independent app/media outage recovery.

**Architecture:** Keep existing Android admission and native channels. Share a
pending playback promotion and fence completion/cleanup by generation. Use the
existing paired Android/Web harness with externally verified, owned-container
faults; retain original reports and add a separate fault timeline/assessment.

**Tech Stack:** Flutter/Dart, Android FGS, isolated Go/LiveKit/Docker, Playwright.

## Operating brief

- workflow_class=split_first; task_size=large; structure_mode=structure_no_rg.
- Backlog owner T-022 (dependencies T-006/T-020); existing requirements unchanged.
- Leaf: `clients/flutter/lib/src/features/voice/background_playback/session.dart`.
- Native edge: `VoicePlaybackPlugin.kt`; consumer `background_playback/sync.dart`.
- Preserve foreground-only admission, mute/deafen/listener intent, fail-closed
  cleanup, no background restart and no native calls outside Android.
- Limits: 120 lines/file, 16 production/direct test files per leaf.
- Base: master `4a532e4c67d5322f9cec8fc350390227d7653b21`.
- Stop condition: nearest regressions + native listener and independent recovery
  cases reviewed; CI green, merge verified, issue updated with remaining gates.
- Open hardware gates: no attached physical Android; no iPhone/iOS runtime here.

## Task 1 — playback lifecycle implementation

- [x] Run existing playback/session/controller tests as preservation baseline.
- [x] Add `test/features/voice/background_playback/start_races_test.dart` with
  concurrent native admission, stale failure and native-stop replacement cases.
- [x] Observe failures before changing production code.
- [x] Fence/share starts in `background_playback/session.dart`, retaining timeouts.
- [x] Run focused tests/analyzer and register the scenario/parity decisions in
  `tools/qa/local_features/features.json`.

## Task 2 — isolated native acceptance

- [x] Use the dedicated API35 x86_64 AVD and an independent browser participant.
- [x] Run listener background/resume with decoded sample and FGS checks.
- [x] Pause only the owned Go API for 60 seconds while media remains healthy;
  verify receiver progress, unchanged Room/track, FGS and return to app readiness.
- [x] Pause only the owned LiveKit for 15 seconds; measure the actual RTP pause
  and recovery against a 15-second post-restore target. Preserve failures.
- [x] Inspect native captures at source resolution; record exact source hashes,
  environment, fault verification and limitations. Do not equate RTP with hearing.


- [x] Fence UI synchronization replies after deafen/undeafen; regress three races.
- [x] Diagnose API33 resume ANR; allow live test frames during resume wait,
  restore prior frame policy, and verify unit plus fresh native runs.

## Task 3 — review and delivery

- [x] Run native Contracts and registered local checks; retain all failed attempts.
- [ ] Complete final preflight/manual review and hosted CI before merge.
- [ ] Commit explicit paths only, open PR and await exact-head required CI.
- [ ] Merge with expected head; verify master parents/tree and a clean worktree.
- [ ] Update #785 without closing physical/iOS/release gates that have not passed.
