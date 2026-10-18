# Mini-player acceptance — #247 / FV2-055 — 2026-10-18

**PASS for the established Web, Android emulator and iOS Simulator matrix:**
9 Web checks and 10 checks on each native target. This supersedes the incomplete
2026-10-12 acceptance for this matrix; that earlier failure record is retained.

The native runner used to overwrite the caller's Docker context and put the
Homebrew Flutter installation before the selected SDK. It now preserves the
isolated context/configuration and honors `FLUTTER_ROOT`. Three focused tests
failed before this change and passed afterward; all 13 mini-player harness
tests pass. Application and media dependency code are unchanged.

## Source and environment

- Application source: master `1557cfce4330bcbf80dff316241119f553b49ef3`;
  native version `1.0.43+78`, debug integration target, Flutter 3.47.7 /
  Dart 3.13.5. The JSON records full library, executable, driver and handler hashes.
- Web: production Vite build, Chromium; browser/host and source/build manifests
  are in the JSON. Build completed before acceptance started. An earlier
  overlapping-build diagnostic was excluded.
- Android: owned `BOOHTACORD_QA_278_API35`, API 35 emulator, serial `emulator-5558`.
- iOS: owned `BOOHTACORD QA278 iPhone`, iOS 27.0 build 24A434 Simulator.
- Actual isolated Go API, PostgreSQL and LiveKit SFU. Production Web UI publishes
  a synthetic 640×360 canvas and quiet 440 Hz tone. No API/media transport mocks,
  production accounts, real messages, SDP or session tokens in this evidence.

## Scenarios and observed results

| Scenario | Web | Android | iOS |
| --- | --- | --- | --- |
| Pin, then TEXT / DM / settings; one receiver and retained selection | PASS | PASS | PASS |
| Full → mini → full, Return and fullscreen keep source | PASS | PASS | PASS |
| Stop unsubscribes video/audio once; mute controls output | PASS | PASS | PASS |
| Default unpinned route change stops viewing | PASS | PASS | PASS |
| Source removal / disconnect clears receiver | PASS | PASS | PASS |
| Logout / account switch / actual access revocation clears receiver | PASS | PASS | PASS |
| Responsive controls, names, focus, composer/dock separation | PASS | PASS | PASS |
| Unpinned source republish outside voice does not resubscribe | Included in route/source checks | PASS | PASS |

Native observations retain one renderer and one video/audio subscription with
zero additional subscribe/unsubscribe events across pinned navigation. iOS
decoded frames increase from 69 to 203, audio packets from 163 to 344 across
full/TEXT/DM/settings/Return/fullscreen. Android and Web counters, teardown
checks and every required result are recorded in the JSON.

All 35 synthetic captures were visually inspected: 9 Web, 13 Android, 13 iOS.
Web widths: 320/393/768/1024 CSS px. Native adaptive checks use 320/393 Flutter
view overrides and renderer captures; these are not physical display modes.
Ordinary native scenarios use device screenshots. The 320 captures were also
inspected at source resolution. Mini-player controls are reachable and occupy
separate space from the composer and voice controls. File hashes are recorded;
generated images remain in the ignored local QA output, not in source control.

## iOS failure and recovery

Two current-source attempts failed before acceptance: `SIGABRT` in
`AURemoteIO::Initialize → AudioUnitInitialize` on the WebRTC thread. Opening
Device Hub alone did not resolve it. With no other simulator booted, the owned
simulator was shut down, the exact existing `SimAudioProcessorService` process
was sent `SIGTERM`, and the simulator was booted again. The unchanged,
audio-enabled integrated application then passed all 10 scenarios.

This is an observed environment recovery, not a proven root-cause fix. Audio
was not disabled and dependencies were not changed to obtain PASS. No claim
is made about physical iOS/Android audio quality, desktop native parity or load
capacity. Those checks remain outside this emulator/browser acceptance.

## Reproduction and checks

1. Select an isolated Docker context/config, pinned Node and Flutter SDK;
   production-build `clients/web` into `.out/qa247-build` with
   `VITE_PUBLIC_ORIGIN=https://localhost:4830`.
2. Run `QA_HOLD_FOR_NATIVE=1 python3 -m tools.qa.mini_player.run`.
3. Run `python3 -m tools.qa.mini_player.native --platform ios --device
   57E6A791-8975-4C84-82E6-47321F22C9B8`, then the Android equivalent with
   `--platform android --device emulator-5558`. Use the owned devices above.
4. Release the owned publisher with the harness sentinel after both receivers
   finish. This run removed its private services/credentials and port reverses;
   both devices were returned to their prior stopped state.
5. `python3 -m unittest tools.qa.mini_player.test_environment
   tools.qa.mini_player.test_native`: **13 PASS**. Spec traceability:
   **PASS_INDEX_ONLY**, 39 requirements; approved Windows brief unavailable here.

Exact results, source/build hashes, timings and capture hashes:
[machine-readable evidence](issue247-mini-player-acceptance-2026-10-18.json).
Final exact-head CI and master merge are recorded in the PR and issue after this
evidence commit; they are not asserted as completed in this pre-merge record.
