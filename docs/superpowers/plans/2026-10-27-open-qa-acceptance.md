# Open QA acceptance Implementation Plan

> **For agentic workers:** Execute inline, one verification packet at a time. Use the existing native routes and current user authorization; no delegation or extra handoff question is needed.

**Goal:** Assess every open QA issue against the available Windows PC and physical Android, retain evidence, and file reproducible defects.
**Architecture:** Freeze the live issue criteria as input data, map each criterion to native execution and hardware, then execute bounded packets. Aggregate outcomes never replace a platform result. Product fixes are separate from verification.
**Tech Stack:** GitHub connector, Windows Computer Use, ADB, real production Vue/Flutter clients, Playwright/WebRTC counters, native Go/Python/Flutter validators.

---

## Packet 1 — Intake and operating brief

- [x] Freeze all 37 open issues and original acceptance text in ignored local input.
- [x] Create `evidence/qa/open-issues-2026-10-27/matrix.json`; 480 extracted requirement/dependency rows, per-case execution mapping in progress.
- [x] Revalidate Windows/Android/client/source inventory; provider readiness remains pending. macOS/iOS, Pixel-specific, load and shared-production fault cases remain explicit.
- [x] Search duplicates and inspect #165; native Windows first-frame defect filed as #579.
- [ ] Save each verified packet before advancing. Target 100/hard 120 source lines and 8/hard 16 production/direct test files per leaf; evidence data is not route authority.

## Packet 2 — Screen, voice and roster

Route through `tools/qa/screen_setup`, `tools/qa/roster_runtime`, `tools/qa/macos_sender` and their exact README/import edges only when executing that capability.

- [ ] Reuse source-bound physical evidence at `evidence/android/physical-share-2026-10-27/`; do not rerun passed rows without a new concern.
- [ ] Execute remaining available Android/Windows/Web lifecycle, mute/PTT, preview, permission, reconnect, selected-viewer and populated-roster rows.
- [ ] Capture only safe synthetic/public frames and numeric media counters. No PCM, continuous recording, SDP, credentials or private chat.
- [ ] File confirmed failures with exact versions, steps, expected/actual results, evidence and unresolved causes. Test negatives on owned objects; no global production outage/load.

## Packet 3 — Identity, navigation, chat and storage

Route through the exact capabilities in `tools/qa/quickjump`, `guild_identity`, `mobile_navigation`, `conversation_files`, `dm_composer`, `message_actions`, `mentions_inbox` and `client_parity`.

- [ ] Execute actual Windows/Web/Android task flows with controlled accounts and synthetic conversations.
- [ ] Verify cross-account/DM ACL, drafts, reactions, search, attachments, image viewing, keyboard/IME, Back/focus and no automatic Voice Join.
- [ ] Preserve the user's installed session and settings; restore any scoped test change.
- [ ] Keep global guild rename, actual device hotplug, native readers and destructive shared-state operations dependent on their real prerequisites.

## Packet 4 — Tracing, notification and delivery

Route through `tools/qa/tracing_flow`, `telemetry_delivery`, `desktop_updates`, `trusted_delivery` and the issue's exact native entrypoints.

- [ ] Verify deployed read-only readiness, signed candidate provenance/catalog, telemetry safe outcomes and available provider/device scenarios.
- [ ] Separate local/synthetic validator coverage from real relay/Collector/Tempo/provider/OS delivery.
- [ ] Do not rotate production credentials, deploy/rollback, saturate limits, restart shared services or inject failures without the required environment/authorization.
- [ ] Mark missing iPhone/macOS, external provider credentials, approved load host and release-window requirements as concrete blockers.

## Packet 5 — Reconcile and handoff

- [ ] Every original criterion has an executed result or an explicit prerequisite blocker; none remains silently pending.
- [ ] Recheck failures once with a controlled witness where safe; retain the original failure.
- [ ] Update existing QA issues without removing their criteria and link defect issues/evidence.
- [ ] Close only issues whose entire DoD is actually PASS. A missing platform never becomes PASS.
- [ ] Validate JSON, source/artifact hashes and screenshots; inspect status/sizes, commit only the intended evidence, and publish the branch.
- [ ] Refresh open QA scope and reconcile newly opened QA gates. Finish the goal only after all available work is complete and all remaining hardware/provider/environment blockers are documented.

## Stop conditions and unresolved inputs

A packet stops at a real missing device, provider, credential, unsafe shared-state mutation, user-stop signal or denied tool action. Continue independent packets instead of repeatedly attempting the blocked action. Production origin is `https://v.bootybay.ru`; SHARE_TEST is the user-approved media room. No tests are removed and no consolidation decisions are applied.
