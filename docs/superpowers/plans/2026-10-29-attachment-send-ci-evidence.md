# Attachment send CI evidence implementation plan

> **For agentic workers:** Execute each checked step in order; root owns CI publication changes.

**Goal:** Require both synthetic #598 own-message captures without allowing arbitrary uploads.

**Architecture:** Extend the existing finite Flutter capture inventory. Preserve required profiles, source/run/attempt bindings and unknown-file rejection.

**Tech Stack:** Python unittest, Flutter widget captures, GitHub Actions.

---

### Task 1: Retain the two native widget scenarios

Files: `tools/ci/flutter_gates/test_recent_bug_artifacts.py`, `tools/ci/flutter_gates/recent_bug_visuals.py`, `tools/ci/flutter_gates/test_artifacts.py`.

- [ ] Add `dm-attachment-send-jpeg.png` and `dm-attachment-send-gif.png` to the required set in the existing publication behavior test.
- [ ] Run `python -m unittest tools.ci.flutter_gates.test_recent_bug_artifacts`; expect FAIL because the two required images are absent from `VISUALS`.
- [ ] Append the same two exact names to `recent_bug_visuals.VISUALS`, include #598 in its scope docstring, and update the exact inventory count from 161 to 163 without removing any existing capture.
- [ ] Run `python -m unittest tools.ci.flutter_gates.test_recent_bug_artifacts tools.ci.flutter_gates.test_artifacts tools.ci.flutter_gates.test_notification_artifacts`; expect PASS. The test must still reject every missing required capture and an unknown upload.
- [ ] Run the new Flutter scenarios with `BOOHTACORD_VISUAL_CAPTURE_DIR` set, inspect the generated PNGs at source resolution, and retain source-bound hashes in hosted evidence. A widget capture does not replace physical Android acceptance.

Before staging, inspect status, changed sizes and the precise diff. Stage only named source, test, plan and sanitized evidence files. Hosted CI must collect both captures on the final head before merge.

### Task 2: Distinguish the new signed acceptance candidate

Files: `clients/flutter/pubspec.yaml`, `contracts/client-build.json`.

- [ ] Follow `docs/clients/versions.md`: change the shared Flutter build from `1.0.47+82` to `1.0.47+83` for the new distributed QA binary.
- [ ] Change each native identity to `native_build: "83"`, `release_order: 62`, and its corresponding `*-r62` release ID. Preserve Web identity and the complete production update catalog byte for byte. This prepares a distinct candidate; it does not publish or promote a release.
- [ ] Run `python -m pytest tools/build/test_client_identity.py -q`, native source/manifest tests, and `tools/verify/contracts/verify-contracts.ps1`. Require success before staging.

### Task 3: Record the shared chat platform decision

Files: `tools/qa/local_features/features.json`, `evidence/qa/issue598-parity-review-2026-10-29.json`.

- [x] Preserve hosted attempt 1 contracts failure and reproduce it with `python -m tools.verify.client_parity.run --base 754b5997ad100cb00300373f29ab88bda4ed267d` before editing the registry.
- [x] Set `chat.parity_review.issue` to 598 and append the Android/iOS shared implementation and headless regression decision, unchanged Web regression obligation, and explicit Android/iOS runtime NOT_RUN limits. Preserve existing decisions and all scenario runtime states.
- [x] Run `python -m unittest tools.verify.client_parity.test_policy tools.qa.local_features.test_policy` and the same parity command; require six passing policy tests and successful changed-feature validation. Preserve RED/GREEN hashes and the separate canonical harness bootstrap BLOCKED result.
- [ ] Push the metadata follow-up and require a fresh full hosted CI execution on its final head. Keep attempt 1 failure as history; never weaken the parity gate or reuse its unfinished checks as final-head evidence.
