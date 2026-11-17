# Mobile Web voice lifecycle

The browser voice client provides best-effort recovery when a mobile page returns to the foreground. A browser or operating system may throttle, freeze, or discard a hidden tab, so continuous audio in the background is not guaranteed.

## Resume behavior

- On `visibilitychange`, `pageshow`, `online`, `offline`, and supported `navigator.connection` changes, the visible page re-reads LiveKit media state and audio playback permission separately.
- A signaling-only reconnect is not treated as a media disconnect. A real media disconnect goes through the existing lease-aware, bounded voice recovery flow and still requires current server authorization.
- Application realtime uses its existing heartbeat/liveness recovery, checking stale heartbeat silence on `visibilitychange`, `pageshow`, and supported network changes and reconnecting promptly on `offline`/`online`. A stale application WebSocket does not by itself end a healthy LiveKit session.
- If the browser blocks playback, the voice controls show **«Возобновить звук»**. That action calls LiveKit `startAudio()` from the user's gesture.
- The connected voice panel explains that the browser may pause voice in the background and checks the connection after return. It does not send the user to another client.

## Diagnosis boundary

At base `fa7a41ec3d220b01d3a407e763ac1fe51a489396`, the browser heartbeat monitor handled stale application-WebSocket state on `visibilitychange`/`online`, while `VoiceSession` had no page-resume observer for LiveKit media state. The LiveKit room factory also did not expose playback permission or `startAudio()` to the voice dock, so a resumed page whose browser blocked audio had no explicit recovery action. These are source-confirmed browser failure modes addressed by this change; they do not prove the root cause of the original physical-device report. The Android emulator returned with playback allowed, and its cumulative RTP statistics do not show when packets arrived during the hidden interval. Native Android/iOS root cause remains unconfirmed without the issue's paired device timeline.

## Browser evidence

| Environment or scenario | Result | Evidence limit |
| --- | --- | --- |
| Web unit, build, accessibility, navigation, and voice-interface browser suites | PASS | The issue-specific mobile browser resume UI scenario passed; the broad report remains BLOCKED by one skipped screen-profile test |
| Authenticated real-stack browser lifecycle at 1440px and 393px | PASS | Disposable stack and browser journeys only; not physical mobile background media acceptance |
| Android 15 emulator, Chrome 124; listener joined through the disposable Go/PostgreSQL/LiveKit stack, backgrounded for 10 seconds, then restored | PASS_SCOPED | Observed `visibility:hidden` then `visibility:visible`; voice UI returned to «Голос подключён». Emulator run, one participant, no decoded peer audio assertion |
| Android 15 emulator, Chrome 124; synthetic Chromium microphone sender paired with a listener in Android Chrome, then Home for 12 seconds with CDP detached | PASS_SCOPED for lifecycle, UI and post-return RTP counters | The same tab recorded `visible → hidden → visible`; one connected peer remained and the dock showed «Голос подключён». At the first sample after return, cumulative receiver RTP had risen from 16 packets/9,398 bytes to 711/352,533. Counters do not timestamp packet arrival within the hidden interval and do not prove decoded audio, physical-device behavior or 60-minute acceptance |
| Physical Android Chrome, including lock screen and Wi-Fi/LTE transitions | NOT_RUN | Requires physical device and paired receiver |
| Physical iOS Safari and installed PWA | NOT_RUN | Requires supported iPhone/iOS runtime |
| Decoded audible audio on a physical receiver, long background duration, 60-minute acceptance, or a continuous-background guarantee | NOT_RUN | Emulator RTP counters do not prove audible playback, physical-device behavior, or a background SLA |

The recorded browser and emulator checks are in [the issue #785 QA evidence](../../evidence/qa/issue785-mobile-web-resume-2026-11-17.json). The latest Web local-feature run passed both authenticated real-stack journeys at 1440px and 393px and the registered voice-interface browser suite. Its overall report is BLOCKED because the separate `web-screen_profile` suite has one skipped registered test; the issue-specific browser-resume flow passed. An earlier report failed the screen preview selector after voice stages; that failure did not reproduce in the latest real-stack run, and its cause is unproven.

## Native checks tracked by issue #785

These checks audit existing native configuration and runtime regressions; they do not change the browser path or count as background-media acceptance.

| Platform/check | Result | Limit |
| --- | --- | --- |
| Android 15 emulator: registered app, listener, roster and WebSocket recovery smoke | PASS_SCOPED for the named UI/session/socket scenarios | The listener scenario explicitly does not capture a microphone or measure media packets. The broader report is FAIL on a separate #786 deafen-roster assertion; the Flutter unit gate is BLOCKED by one skipped test. |
| Android release-variant merged manifest, target SDK 36 | PASS_SCOPED | The local APK used the debug keystore for inspection; it is not a production-signed release. The microphone service is private and declares the microphone FGS type. |
| iOS audio-session source audit (`livekit_client` 2.13.0; `WebRTC-SDK` 150.7871.01) | PASS_SCOPED for configuration and ownership | The app configures LiveKit-managed audio from WebRTC engine state; default communication policy is `playAndRecord`/`videoChat` with Bluetooth routing. The WebRTC framework binary is not vendored for direct inspection, and no interruption/route-reset runtime acceptance was available. |
| iOS 27 release-variant build and bundled plist | PASS_SCOPED | Built without code signing. No iOS Simulator runtime/device or physical iPhone was available for lifecycle/media acceptance. |
| Physical Android/iOS 60-minute paired background media acceptance | NOT_RUN | Requires supported physical devices, an independent receiver, and decoded-audio evidence. |

## Related issue status

Checked on 2026-11-17: [PR #773](https://github.com/BOOHTACORD/BOOHTACORD/pull/773) is merged at `b46b79c000bc3168983af27b304c4443a3773ed4`. Its parent [issue #689](https://github.com/BOOHTACORD/BOOHTACORD/issues/689) remains open with realtime, platform, and release gates. [Issue #781](https://github.com/BOOHTACORD/BOOHTACORD/issues/781) remains open for Apple-platform physical acceptance. [Issue #785](https://github.com/BOOHTACORD/BOOHTACORD/issues/785) remains open; this browser evidence does not close those linked gates.
