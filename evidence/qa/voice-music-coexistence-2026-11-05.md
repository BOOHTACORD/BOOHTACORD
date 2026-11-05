# Music/audio coexistence — 2026-11-05

Task: T-061 (REQ-AUDIO-01), dependency T-022. PR #654. Base SHA: `0a5d63e7bdee78a8565950dd98f8d0a4bc0d4002`.

## Changes and initial failures

The LiveKit-owned Android manager defaulted to requesting focus before Dart configured it. iOS automatic recording and native first-recording fallback lacked `mixWithOthers`. The patch requests mixing, preserves communication mode and routing, and explains Windows Communications policy without changing other applications or system settings.

Initial CI run `41986575399` failed the base-aware parity decision check and Windows widget diagnostics interaction (tap below the 800×600 viewport). The Windows help is now a collapsed disclosure; focused tests exercise opening/closing it and reaching diagnostics at 800×600 and 320×480 with text scale 2. Platform presentation uses Flutter's target platform, permitting the Windows widget to be tested on macOS. The original diagnostics test now ensures the actual tap target is visible and hit-testable.

## Local verification

Pinned Flutter 3.47.7, framework `abaf9c523780a608bd46686fd5e53740a07077f8`, Dart 3.13.5.

- Focused Windows widget and diagnostics tests: **PASS**, 7 tests (Windows and non-Windows platform variants). The new disclosure assertions failed before implementation; logs: `.out/pr654/red-guidance.log`, `.out/pr654/green-guidance.log`.
- LiveKit audio-session suite: **PASS**, 52 tests, `.out/pr654/livekit-audio-test.log`. These verify configuration and native channel contracts, not acoustic levels.
- Windows Web guidance keyboard/disclosure, retained controls and non-Windows omission: **PASS**, 3 Chromium tests, `.out/pr654/web-audio-help.log`.
- Finite mandatory screenshot inventory: **PASS**, 7 tests; unknown images and missing guidance captures are rejected.
- Base-aware client parity: **PASS**; Web/iOS/Android decisions recorded for settings, voice and broad shell path coverage.
- Spec traceability: **PASS**, 39 requirements using committed approved index; original approved Windows brief unavailable on this host.
- Contract verifier: **PASS**, including 20 parity tests and 129 public operations. No API contract change.
- Web unit **PASS**, 1,748 tests; full Flutter unit **PASS**, 1,761 passed / 1 skipped; selected component suite **PASS**, 616 tests.
- Full LiveKit suite **PASS**, 452 passed / 1 skipped. Focused changed-file analysis **PASS**, no issues.
- Full Python verification **PASS**, 1,363 run / 9 skipped, after correcting macOS test-host configuration (direct temporary directory outside Git, private Compose plugin).
- Android emulator and iOS Simulator owned-API authentication, workspace, profile/audio/admin panels and logout: **PASS**. The stale native test searched for the removed `Дополнительно` control; it now exercises visible processing and actual diagnostic expansion/collapse with retained processing state. The iOS SPM build passed; the CocoaPods fallback copy is byte-identical, not separately built.
- Web real API/SFU at 1440 px and 393 px: **PASS** after retries. Original report `.out/local-features/20261105-111959/report.json` remains **FAIL**; it was not overwritten or promoted. Initial Docker/Android failures and the first mobile thumbnail timeout are retained in the supplemental receipt. The fresh 393px run passed after shutting down completed native QA targets, with unchanged timeouts/assertions.
- Supplemental source hashes, screenshot sizes/hashes, exact scopes and failures: `evidence/qa/voice-music-coexistence-local-2026-11-05.json`.
- Local runner invoked the same `tools.qa.local_features.run` entrypoint as `check.sh` with its SDK/JDK/Docker bootstrap, preserving pinned Flutter 3.47.7 first on PATH (the shell wrapper prepends the globally installed 3.47.6). Selected features: auth, connection_status, screen, settings, shell, support, voice; base above; `--real-stack`; Web/Android/iOS. Native and Web reruns used their existing runner modules, with fresh mobile output.
- Vendor `scripts/check_version.dart`: **FAIL**, pre-existing; its upstream WebRTC-SDK matcher does not recognize this project's pinned macOS `BoohtacordWebRTC` dependency. Neither dependency pins nor that script changed. This advisory is separate from the repository CI gates.

## Visual observations

Inspected original-resolution widget captures in `.out/pr654/captures/`:

- `audio-coexistence-windows-collapsed.png` (800×600): disclosure has a clear title/chevron; diagnostics is visible below, no text overlap.
- `audio-coexistence-windows-expanded.png` (800×600): Windows instructions wrap within the playback card, diagnostics remains reachable, no horizontal clipping.
- `audio-coexistence-windows-large-text.png` (320×480, scale 2): title and instruction text wrap within the card and vertical scrolling is necessary; the existing toolbar ellipsizes its title while retaining back/refresh actions. The test scrolls to and successfully opens diagnostics; no overflow exception.

No screenshot baseline was approved. No original Windows screenshot is available; the initial CI failure is the recorded before-state. Component captures do not establish native runtime or physical audio acceptance.

## Remaining media acceptance

Windows native, Windows Web, Android, iOS external music levels and wired/speaker/Bluetooth profile checks: **NOT_RUN**, physical devices unavailable (confirmed by the user). No claim that `mixWithOthers` alone defeats every OS/driver/voice-processing attenuation behavior. QA simulators cannot prove this.

Release/media gate: **BLOCKED** until physical acceptance from `docs/clients/audio-coexistence.md` is performed and reviewed. Source/CI success is recorded independently of that gate.

The source-only LiveKit hash receipt is extended without changing historical evidence; `backlog/tasks.yaml` remains identical to master. The final GitHub CI result is recorded on PR #654 separately from the blocked physical-media gate.
