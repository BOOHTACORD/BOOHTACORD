# Mobile Web voice lifecycle

The browser voice client provides best-effort recovery when a mobile page returns to the foreground. A browser or operating system may throttle, freeze, or discard a hidden tab, so continuous audio in the background is not guaranteed.

## Resume behavior

- On `visibilitychange`, `pageshow`, `online`, `offline`, and supported `navigator.connection` changes, the visible page re-reads LiveKit media state and audio playback permission separately.
- A signaling-only reconnect is not treated as a media disconnect. A real media disconnect goes through the existing lease-aware, bounded voice recovery flow and still requires current server authorization.
- Application realtime uses its existing heartbeat/liveness recovery, checking stale heartbeat silence on `visibilitychange`, `pageshow`, and supported network changes and reconnecting promptly on `offline`/`online`. A stale application WebSocket does not by itself end a healthy LiveKit session.
- If the browser blocks playback, the voice controls show **«Возобновить звук»**. That action calls LiveKit `startAudio()` from the user's gesture.
- The connected voice panel explains that the browser may pause voice in the background and checks the connection after return. It does not send the user to another client.

## Short reproduction versus release acceptance

The issue-specific emulator regression uses a 120-second (two-minute) background interval. That is the fast reproduction window; rerunning it for an hour does not improve diagnosis of a failure that appears within two minutes.

The issue's separate physical release gate still asks for a 60-minute paired Android/iOS background acceptance with audible media evidence. Emulator runs, including an existing 60-minute Android Chrome listener run, do not satisfy that physical-device gate. Keep the short regression and the physical release acceptance as distinct checks.

## Diagnosis boundary

At base `fa7a41ec3d220b01d3a407e763ac1fe51a489396`, the browser heartbeat monitor handled stale application-WebSocket state on `visibilitychange`/`online`, while `VoiceSession` had no page-resume observer for LiveKit media state. The LiveKit room factory also did not expose playback permission or `startAudio()` to the voice dock, so a resumed page whose browser blocked audio had no explicit recovery action. These source-confirmed browser failure modes were addressed by [PR #824](https://github.com/BOOHTACORD/BOOHTACORD/pull/824); they do not prove the root cause of the original physical-device report.

The Android Chrome emulator runs show bounded lifecycle and RTP behavior in the recorded scenarios. The Android Flutter microphone pair shows FGS and receiver RTP continuity through Home/screen-off, and shows RTP pause/recovery during a controlled AVD loopback outage. None of these runs reproduces a physical Wi-Fi/LTE interface transition or establishes audible output. Native Android/iOS root cause remains unconfirmed without the issue's physical paired timeline.

## Browser evidence

| Environment or scenario | Result | Evidence limit |
| --- | --- | --- |
| Web unit, build, accessibility, navigation, and voice-interface browser suites | PASS_SCOPED | The issue-specific mobile resume UI scenario passed. The broader report remains BLOCKED by one skipped screen-profile test. |
| Authenticated real-stack browser lifecycle at 1440px and 393px | PASS | Disposable stack and browser journeys only; not physical mobile background media acceptance. |
| Android 15 emulator, Chrome 124; listener backgrounded in Android Home for 60 minutes | PASS_SCOPED | Receiver RTP counters were 18 before background, 180,138 at resume, and 181,645 after 30 seconds. This is an AVD listener scenario; counters do not prove acoustic output or physical-device behavior. [Evidence](../../evidence/qa/issue785-android-chrome-background-hour-2026-11-18.json). |
| Android 15 emulator, Chrome 124; issue-specific Home/resume scenario | PASS_SCOPED, 121.604 seconds | Receiver RTP counters advanced from 23 packets to 6,109 at resume and 7,616 after post-resume samples. This AVD result does not prove packet timing during each hidden interval or audible output. [Evidence](../../evidence/qa/issue785-android-chrome-background-resume-2026-11-21.json). |
| Earlier Android Chrome lifecycle smoke (10-second listener and 12-second paired synthetic sender) | PASS_SCOPED | These short runs establish lifecycle/UI and post-return counters only; they do not replace the 120-second scenario, physical device, decoded-audio, or release gates. [Evidence](../../evidence/qa/issue785-mobile-web-resume-2026-11-17.json). |
| Physical Android Chrome, including lock screen and Wi-Fi/LTE transitions | NOT_RUN | Requires a physical device and paired receiver. |
| Physical iOS Safari and installed PWA | NOT_RUN | Requires a supported iPhone/iOS runtime. |
| Audible audio on a physical receiver, or a continuous-background guarantee for mobile Web | NOT_RUN / NOT_PROMISED | Emulator RTP counters do not prove audible playback; browsers may suspend hidden pages. |

The mobile Web recovery flow and warning are in [PR #824](https://github.com/BOOHTACORD/BOOHTACORD/pull/824), merged at `daa96b53ff1cee6d8629428e85afeb76bdb7c553`. Its issue-specific browser tests and authenticated real-stack journeys passed. The broader registered report was BLOCKED by one skipped `screen_profile` publisher/viewer test; that is separate from the issue-specific voice-resume scenario.

## Native checks tracked by issue #785

These checks audit existing native configuration and runtime regressions; they do not change the browser path or count as physical background-media acceptance.

| Platform/check | Result | Limit |
| --- | --- | --- |
| Android Flutter microphone publisher + independent browser listener, Home | PASS_SCOPED, 120.004 seconds | Mic FGS was active at all five background samples; receiver counters advanced 21→583 packets and 3,945→48,484 bytes; the same Room and mic track remained after resume. No acoustic output was measured. [Evidence](../../evidence/qa/issue785-android-microphone-uplink-background-2026-11-21.json). |
| Android Flutter microphone publisher + independent browser listener, display asleep | PASS_SCOPED, 120.001 seconds | Display was asleep at all five samples, mic FGS stayed active, and receiver RTP advanced 18→580 packets. This does not assert secure keyguard or audible output. [Evidence](../../evidence/qa/issue785-android-microphone-uplink-screen-off-2026-11-21.json). |
| Android Flutter microphone pair with injected AVD loopback API/LiveKit outage | PASS_SCOPED, 120.010 seconds total; outage 30.098 seconds | Firewall dropped 735 UDP media packets and 528 TCP signaling/API packets; receiver RTP paused and resumed 3.331 seconds after rule removal; mic FGS stayed active at all six outage samples. This is endpoint-scoped AVD loopback, not Wi-Fi/LTE switching or physical audibility. [Evidence](../../evidence/qa/issue785-android-microphone-uplink-blackhole-2026-11-21.json). |
| Android listener-only background playback | PASS_SCOPED, 120.002 seconds | Playback FGS stayed active and decoded samples covered the Home interval; mic FGS was inactive. Acoustic output was NOT_MEASURED. [Evidence](../../evidence/qa/issue785-android-background-playback-2026-11-20.json). |
| Android release-variant merged manifest, target SDK 36 | PASS_SCOPED | The private microphone FGS and permission declarations are present. A QA-signed emulator build is not a production-signed release or production smoke. [Evidence](../../evidence/qa/issue785-android-release-manifest-emulator-2026-11-18.json). |
| iOS audio-session source audit (`livekit_client` 2.13.0; `WebRTC-SDK` 150.7871.01) | PASS_SCOPED for configuration and ownership | The app configures LiveKit-managed audio from WebRTC engine state; default communication policy is `playAndRecord`/`videoChat` with Bluetooth routing. The WebRTC framework binary is not vendored for direct inspection, and no interruption/route-reset runtime acceptance was available. |
| iOS release-variant build and bundled plist | PASS_SCOPED | Built without code signing. No iOS Simulator runtime or physical iPhone was available for lifecycle/media acceptance. |
| Physical Android/iOS 60-minute paired background media acceptance | NOT_RUN | Requires supported physical devices, an independent receiver, and audible-media evidence. |

Every Android runtime result above is scoped to an AOSP emulator. The issue remains open for physical Android/iOS acceptance, the Safari/PWA device matrix, network and OS-interruption scenarios, production-signed artifacts, and production smoke/rollback.

## Related issue status

Checked on 2026-11-21: [PR #773](https://github.com/BOOHTACORD/BOOHTACORD/pull/773) is merged at `b46b79c000bc3168983af27b304c4443a3773ed4`. Its parent [issue #689](https://github.com/BOOHTACORD/BOOHTACORD/issues/689) remains open with realtime, platform, and release gates. [Issue #781](https://github.com/BOOHTACORD/BOOHTACORD/issues/781) remains open for Apple-platform physical acceptance. Issue #785 remains open; emulator and browser evidence do not close its physical or release gates. Latest Android microphone pair test tooling is in [PR #834](https://github.com/BOOHTACORD/BOOHTACORD/pull/834), merged at `81641df88ce09054ff47920791c965e630eb3e0c`; its hosted CI passed 27/27 jobs.
