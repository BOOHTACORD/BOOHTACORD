# Issue 785: Android microphone start generation

Date: 2026-11-27. Result: **PASS_SCOPED** for the lifecycle fix and the
three paired emulator cases below. The full issue and release gate remain open.

## Source and reproduced defect

Base: `0173e6a82b43497c7a7ba79a967c83a2aa429b30` (master).
Backlog scope: T-022, voice admission/controls/recovery; dependencies T-006/T-020.
The implementation leaf is Flutter `voice/background_microphone/session.dart`.

The existing nine session/controller tests passed before the change. Three new
deferred-response behavior tests failed against unchanged master:

- Two concurrent starts issued two native requests, although the plugin rejects
  a second pending promotion. The Dart session now shares the pending request.
- A failed obsolete start called `stop()` after a replacement had become active.
  Cleanup is now permitted only for the same live generation.
- A native `stopped` notification did not invalidate a pending successful reply;
  that reply could restore `active=true`. Native loss now invalidates the reply.

These are deterministic Dart/MethodChannel reproductions, not proof that every
historically reported physical-device disconnection had this cause. Native
foreground/permission admission, timeouts, explicit leave and mute intent remain.

Candidate LF-normalized SHA256 (Windows build and Linux QA copies matched):

| File | SHA256 |
| --- | --- |
| `clients/flutter/lib/src/features/voice/background_microphone/session.dart` | `8d2fb29a80aa44eb96de0a5d742bb3a8cfaad0212280199b4145e76356d7e5f4` |
| `clients/flutter/test/features/background_microphone/start_races_test.dart` | `087898aa0ca9f6f05d0c4213153ea34e31336be4d507a0a0019b98be4ef4cb30` |
| `tools/qa/local_features/features.json` | `fc176ba21e21df981bfb61b99fac4bf99c94926ae8d854d375f59354070d5ffe` |

## Observed checks

- `flutter test test/features/background_microphone --reporter expanded`: 19 PASS.
- Focused `flutter analyze --no-pub`: PASS, no issues.
- Full Windows-host `flutter test --no-pub --concurrency 2 --reporter expanded`:
  exit 0, 2069 passed, 3 skipped (opt-in real telemetry export and two macOS-only
  updater tests). Skipped cases are not claimed as passed.
- `python -m tools.ci.native.contracts`: exit 0; main Python suite 1877 tests,
  28 declared platform/environment skips, plus the native contract checks.
- Dart dependency boundaries, client parity and product-map generation checks:
  PASS. Exact-head hosted CI and broad registered profile results are recorded in
  the PR and issue; this receipt does not substitute for those gates.

## Paired Android runtime

Actual device: **Android 15/API35 x86_64**, dedicated `BOOHTACORD_QA_R1_1121`,
`emulator-5580`, targetSdk36, debug 1.0.60+96. Windows 11 Pro 10.0.26300,
Flutter 3.47.7/Dart 3.13.5. Windows Flutter built the candidate; a WSL-owned
Go/PostgreSQL/Caddy/LiveKit stack and independent Chromium listener supplied real
auth, application sockets and media. LiveKit image:
`livekit/livekit-server:v1.13.7@sha256:6fd3b7088874c4d119160dd688798dfec852bc014786d392caad15f6f63912a3`.

Command: `python -m tools.qa.critical_client_acceptance.issue785_android_flutter_uplink_pair`
with `--device emulator-5580 --background-seconds 120 --output <fresh-directory>`.
The Windows/WSL bridge only adapted tool paths and Dart-define/capture paths.
All three runs used the same candidate production bytes and the repository's
existing integration test/harness.

| Case / additional argument | Observed result |
| --- | --- |
| Home | 120.000 s monotonic background; FGS active at 0/30/60/90/120 s; same Room and microphone track after resume; receiver 18→630 packets, 3634→52135 bytes across 60 in-window samples; leave stopped FGS. |
| `--service-stop-after-seconds 5` | External adb stopService, not an OS-forced kill. FGS inactive at 30/60/90/120 s; same Room/socket, muted unavailable listener after resume; no automatic FGS restart. Explicit Retry restored connected/unmuted state and FGS in the same Room; independent RTP advanced 95→99 packets within 4.701 s of Retry. Leave stopped FGS. |
| `--background-action screen-off` | 120.000 s; display asleep and FGS active at all five observations; same Room/track on return; receiver 30→644 packets, 4585→53244 bytes across 60 in-window samples; leave stopped FGS. Secure keyguard not asserted. |

Raw results are retained under the Linux clone's ignored `.out/` directory.
Their SHA256 values, respectively:

- `native-home-r2/result.json`: `2b385651fcf1ccfd9bbe9a4dc12b06d461894aabf4177faed3f821da51619e24`
- `native-service-stop/result.json`: `00d25da9786860d203db9d4c858d9fce1c62970f86d7f78822728b3d2c4c6679`
- `native-screenoff/result.json`: `f93bf135c46f129a32a2382a7ec1ef49f40fcbbf2ecfb80f36a89b7421c9978e`

Provenance correction: the legacy runner hardcodes ARM64/API35 AVD labels and
`working_tree_clean_product_source=true`. Those fields are not valid for this
Windows/x86_64 candidate run; the actual environment and dirty candidate hashes
above are authoritative. They must not be presented as clean-master execution.
An initial wrapper download stalled in an empty Gradle cache before device tests;
its failed run was retained separately, then the installed cache was used.

## Visual review and open gates

Inspected native 1080×2400 `android-recovery-2.png` at source resolution: listener
heading, full service-loss warning, microphone-unavailable panel and Retry button
are visible; leave remains reachable. SHA256:
`51966a10a9e132cdaa8132c1f64d9e461f8fb205d3525b2fe0bc9cc3f14171e3`.
The two earlier launcher/transition captures are not accepted UI evidence.

RTP is transport evidence; acoustic output, physical 60-minute voice, secure lock,
Doze, physical network/device routing, API33/34, iPhone/iOS and installed release
acceptance remain NOT_RUN/BLOCKED. No production deployment or release is attested.
