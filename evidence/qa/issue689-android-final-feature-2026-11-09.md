# Issue 689: Android feature gate, 2026-11-09

- Source: `72928320db20baa1ca7c9810d5a7bafe7e8a7533`, dirty worktree SHA-256 `5d3ea50601e183f8227ea877b296bd6290212df0fee982a3577f167fdbb69f7d`; source stability PASS. This is not an immutable release artifact.
- Runner: dedicated `BOOHTACORD_QA_ISSUE689` Android emulator, disposable local API and LiveKit. Registered features: auth, chat, connection_status, screen, shell, support, telemetry, voice.
- Android runtime, issue689 listener, and issue689 roster: PASS. Listener exercises a real LiveKit room through application WebSocket disconnect and recovery; it does not validate physical audio capture or audio quality.
- Flutter unit: BLOCKED, three skipped tests. One native telemetry export test requires an isolated Tempo relay; two desktop recovery tests require macOS. Flutter component captures: BLOCKED, the same telemetry test skipped once. A separate successful test must not be represented as an unskipped full-suite run.
- Visual review: 3 of 192 images inspected at original resolution. The roster image shows an empty voice channel; the listener recovery image shows a connected voice room and one participant; the maintenance image shows the unknown-status warning on the sign-in screen. Remaining visual review NOT_RUN.
- Raw local report: `.out/local-features/20261109-112624/report.json` (generated locally, not tracked). Overall acceptance remains BLOCKED; physical-device, macOS, iOS and release-artifact checks remain unproven.

## Separate native telemetry test

`TestNativeSDKExportsRenderedFlowToTempo` with the pinned Windows Flutter test engine, a synthetic principal and isolated local Collector/Tempo: PASS (one Flutter test, 53.94 s). The test checks the actual SDK and rendered-frame observer through the production relay handler into Tempo, including exclusion of synthetic message text. It uses a test principal and Flutter test engine, not an installed Android application or real login. The owned Collector/Tempo containers, test volume and network were removed. The full Flutter suite and component capture reports above still record their original skips and remain BLOCKED; two other tests require macOS.
