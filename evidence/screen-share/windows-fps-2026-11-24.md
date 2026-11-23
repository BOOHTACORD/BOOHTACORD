# Windows FPS capture and live profile changes

Date: 2026-11-24. Base: `6db64afd72b857fbb19213681f10ae7ff52f9d12`.
Branch: `codex/windows-screen-fps`. Related historical issue: #166;
the broader physical matrix in #664 is not closed by this work.

## Established defects and changes

- An active Windows capture retained its initial FPS after a settings change.
  The controller now stops/recreates only the screen publication, retaining the
  selected source, screen-audio option, dimensions and content mode. Explicit
  Stop, logout, room replacement or a new source request cancels stale restarts.
  Automatic changes retain the user's quality ceiling.
- The Windows SDK's legacy window path used GDI. Use the upstream optional
  compositor-backed WGC window path, retaining the visible capture border and
  OS-capability fallback. Do not focus another window during source selection.
  Full-display capture retains the SDK's existing DirectX path.
- A constant SDK archive/extraction path could reuse an older binary despite
  a changed version pin. Windows now uses version/architecture-specific caches
  and verifies release-archive SHA-256 before loading the SDK.

Windows SDK: `libwebrtc.m150.7871.07`; upstream source
`4515f9ccdca75e2454e204f326f1d7129cad678e` at
<https://github.com/webrtc-sdk/libwebrtc-wrapper>.
The x64 release archive digest is
`0cf141cd803af8f860080d94861d2d591ab9081a28f5cdead1b7c775ad5d3bf8`;
the runtime DLL digest is
`5c9c21dd84091f6d2ca826201bc8e9226e17c0b336f08be634331745584fbb44`.
Linux and Darwin SDK pins are unchanged.

## Verification scope and method

Windows 11, Flutter 3.47.7 / Dart 3.13.5; Intel UHD 770 and NVIDIA RTX 5080.
The QA entrypoint is `integration_test/windows_screen_fps/main.dart`; it must
never be packaged as the ordinary app. A separate owned window renders a
synthetic animation. A second process uses real native capture, the shipping
NativeScreenShareDriver and ScreenShareController, and an independent native
LiveKit subscriber/decoder. Only numeric counters are retained: no captured
pixels, microphone audio, SDP, media or access tokens are saved.

The disposable SFU is LiveKit v1.13.7, image digest
`sha256:6fd3b7088874c4d119160dd688798dfec852bc014786d392caad15f6f63912a3`,
with host ports bound to loopback, synthetic credentials and a dedicated room.
Each sample warms up for 3 seconds, then measures encoded/decoded frame deltas
for 8 seconds. This measures throughput, not physical display presentation.

Before the native change, direct native peer probes produced about 12/20/30
decoded FPS for requested 15/30/60; a 1 ms timer-resolution experiment did not
improve those values. These early captures were not visually accepted as
moving-content evidence: the probe initially rendered a blank window until a
resize. The later scene uses explicit expanding layout and a visible label;
two source-resolution native screenshots showed cyan bars at different
positions across the complete window before the final measurement.
No hard 15-FPS ceiling was reproduced in these fresh-capture probes.

The final visible-animation SFU sequence completed with these results:

| Requested FPS | Encoded FPS | Remote decoded FPS | Controller recapture |
| --- | --- | --- | --- |
| 15 | 14.37 | 14.25 | Initial capture |
| 30 | 27.62 | 27.49 | Yes |
| 60 | 50.74 | 50.74 | Yes |
| 15 | 14.37 | 14.37 | Yes |

The publisher room remained connected after every step. VP8 sender quality
limitation was `none` for the 30/60/return-to-15 samples. Final 60-FPS encoded
size was 1482x1071. These short observations prove output above 15 FPS in this
owned setup; they do not promise 60 FPS for all content/devices/networks.

## Focused checks

- PASS: 75 Dart tests with `flutter test --no-pub test/screen_scope
  test/features/screen/capture test/screen_share_capture_plan_test.dart
  test/screen_share_quality_test.dart --reporter expanded`.
- PASS: focused Dart analysis of capture/quality/lifecycle, new regression tests
  and the Windows FPS integration entrypoint.
- PASS: native C++ factory regression runs during the Windows plugin build;
  it asserts WGC opt-in, original source/cursor, no forced focus, visible border.
- PASS: `python -m unittest tools.build.windows.test_webrtc_sdk_cache -v`
  (2 tests); stale-cache selection and bad cached digest were exercised.
- PASS: `python -m tools.verify.dependencies.dart` and
  `pwsh -NoProfile -File tools/verify/contracts/verify-contracts.ps1`.
- PASS: ordinary `python -m tools.build.windows.run` compiled shipping main,
  checked native imports and produced the manifest for Windows 1.0.60+96/r75.
  Initial packaging was BLOCKED by the absent pinned .NET SDK, then by locale
  decoding; SDK 8.0.426 was installed separately, and the unchanged packager
  succeeded with `PYTHONUTF8=1` and `DOTNET_CLI_UI_LANGUAGE=en`.
- PASS: ordinary candidate launched and rendered the authenticated workspace
  without starting a voice call. No chat content or UI screenshot is retained
  in this record. The existing installed client was not replaced.
- The installer/full package are local unsigned candidates, not public releases.
  The measured manifest records signing and working-tree state explicitly.
  Hosted CI and the broad actual/physical matrices remain open required gates.

## Limits that remain open

The exact user's 15-FPS episode is not independently reproduced. Production
network conditions, a Web receiver, physical presentation, voice/screen-audio
continuity and long-running load are not established by a local video-only
probe. Recapture changes the screen publication SID; it does not preserve the
old track identity. Connection state is checked, but no audible continuity
claim is made. A requested 60 FPS is a ceiling, not a guaranteed output rate.
Full-display capture and mixed-client reception need their own acceptance.
The harness does not supply preview source dimensions: captured/encoded size
can exceed the nominal 720p profile; this run is not resolution acceptance.

No production server or public update feed is changed by this packet.
