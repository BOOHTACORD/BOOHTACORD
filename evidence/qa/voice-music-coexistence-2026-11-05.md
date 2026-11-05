# Music/audio coexistence — 2026-11-05

Task: T-061 (REQ-AUDIO-01), dependency T-022. PR #654. Base SHA: `0a5d63e7bdee78a8565950dd98f8d0a4bc0d4002`.

## Changes and initial failures

The LiveKit-owned Android manager defaulted to requesting focus before Dart configured it. iOS automatic recording and native first-recording fallback lacked `mixWithOthers`. The patch requests mixing, preserves communication mode and routing, and explains Windows Communications policy without changing other applications or system settings.

Initial CI run `41986575399` failed the base-aware parity decision check and Windows widget diagnostics interaction (tap below the 800×600 viewport). The Windows help is now a collapsed disclosure; focused tests exercise opening/closing it and reaching diagnostics at 800×600 and 320×480 with text scale 2. Platform presentation uses Flutter's target platform, permitting the Windows widget to be tested on macOS. The original diagnostics test now ensures the actual tap target is visible and hit-testable.

## Local verification

Pinned Flutter 3.47.7, framework `abaf9c523780a608bd46686fd5e53740a07077f8`, Dart 3.13.5.

- Focused Windows widget and diagnostics tests: **PASS**, 3 tests. The new disclosure assertions failed before implementation; logs: `.out/pr654/red-guidance.log`, `.out/pr654/green-guidance.log`.
- LiveKit audio-session suite: **PASS**, 52 tests, `.out/pr654/livekit-audio-test.log`. These verify configuration and native channel contracts, not acoustic levels.
- Windows Web guidance keyboard/disclosure, retained controls and non-Windows omission: **PASS**, 3 Chromium tests, `.out/pr654/web-audio-help.log`.
- Finite mandatory screenshot inventory: **PASS**, 7 tests; unknown images and missing guidance captures are rejected.
- Base-aware client parity: **PASS**; Web/iOS/Android decisions recorded for settings, voice and broad shell path coverage.
- Spec traceability: **PASS**, 39 requirements using committed approved index; original approved Windows brief unavailable on this host.
- Contract verifier: **PASS**, including 20 parity tests and 129 public operations. No API contract change.
- Full local feature acceptance with real API/SFU and Android/iOS QA targets: **RUNNING**. Results will be recorded separately before completion.

## Visual observations

Inspected original-resolution widget captures in `.out/pr654/captures/`:

- `audio-coexistence-windows-collapsed.png` (800×600): disclosure has a clear title/chevron; diagnostics is visible below, no text overlap.
- `audio-coexistence-windows-expanded.png` (800×600): Windows instructions wrap within the playback card, diagnostics remains reachable, no horizontal clipping.
- `audio-coexistence-windows-large-text.png` (320×480, scale 2): title and instruction text wrap within the card and vertical scrolling is necessary; the existing toolbar ellipsizes its title while retaining back/refresh actions. The test scrolls to and successfully opens diagnostics; no overflow exception.

No screenshot baseline was approved. No original Windows screenshot is available; the initial CI failure is the recorded before-state. Component captures do not establish native runtime or physical audio acceptance.

## Remaining media acceptance

Windows native, Windows Web, Android, iOS external music levels and wired/speaker/Bluetooth profile checks: **NOT_RUN**, physical devices unavailable. No claim that `mixWithOthers` alone defeats every OS/driver/voice-processing attenuation behavior. QA simulators cannot prove this.

Release/media gate: **BLOCKED** until physical acceptance from `docs/clients/audio-coexistence.md` is performed and reviewed. Source/CI success is recorded independently of that gate.
