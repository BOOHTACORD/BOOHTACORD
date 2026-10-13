# BOOHTACORD patches

This package is based on the `livekit_client` 2.13.0 release. Its upstream
license and source are retained.

ScreenShareCaptureOptions carries an optional macOS `captureEngine` through
construction, `copyWith` and `video.mandatory` constraints without altering exact
source selection, audio or FPS. `baseline` preserves existing capture routes;
`screen_capture_kit` is an explicit new-start candidate independent of codec.
An omitted engine keeps upstream constraints unchanged. Keep
`test/options/screen_capture_engine_test.dart` when rebasing. This vendored patch
does not change package versions/pins or claim device/performance acceptance.

Optional nullable macOS `captureDiagnosticsEnabled` is forwarded at capture
start through construction, `from`, `copyWith` and `video.mandatory`. Omission
preserves native instrumentation default true. Explicit false removes metrics
and capture snapshots: configuration/actual-frame health is unavailable and the
confirmed-profile writer remains pending. Continuous clocks needed for queue
policy stay active. Same-artifact off/on QA must disclose this metadata-writer
confound; polling off alone is not instrumentation off. Eight focused options
tests cover both seams, including explicit false preservation. Native pipeline
source is unchanged by this SDK option.

The local change aligns the SDK's bounded reconnect delays and jitter with the
web client's `BoundedVoiceReconnectPolicy` in
`clients/web/src/voice/bounded_voice_reconnect_policy.ts`. Keep the focused policy
test in `test/core/voice_reconnect_policy_test.dart` when rebasing a future
LiveKit SDK update.

`VideoEncoding` also carries an optional `scaleResolutionDownBy` value through
`toRTCRtpEncoding()`. Android screen-share profiles use this to cap the longer
edge of a real MediaProjection source while preserving portrait/landscape
aspect ratio. Keep `test/utils_test.dart` coverage for the RTP parameter.
The application derives the even-pixel scale from the selected profile and
reported capture dimensions; see
`clients/flutter/lib/src/services/screen_share_quality.dart` and
[QA-88](../../../../evidence/flutter/qa88-android-screen-share-resolution-cap-2026-09-29-001.json).

All local video sender parameter writes use one SDK-owned lock per
`RTCRtpSender`, and unpublish invalidates queued writes before removing senders.
The screen-share profile API unpublishes and republishes the same capture so
the next `AddTrackRequest` carries matching dimensions and layer descriptors.
Publication disposal can retain that capture only for this managed transition;
the application stops it when the share ends. The app keeps Android simulcast
disabled until device and receiver acceptance is recorded. Focused regressions
are in `test/track/sender_encoding_profile_test.dart` and
`clients/flutter/test/screen_scope/quality_update_test.dart`.
On targets where screen-share simulcast is enabled, the SDK caps the low layer
at 15 fps while retaining the selected frame rate on the original layer.
The retirement gate regression in `test/track/sender_parameter_retirement_test.dart`
covers writes queued after the drain barrier but before sender removal.

## Source and maintenance policy

[UPSTREAM.json](UPSTREAM.json) pins the published upstream archive SHA-256,
license and changed source files, measured against the verified pub.dev archive.
The local overrides remain required. Return to upstream only after the fixes
are included and the focused tests plus affected platform media acceptance pass.

Additional retained patches cover AGP built-in Kotlin compatibility, local audio
RTT statistics, screen publication discovery before subscription, and bounded
video-renderer first-frame callbacks. The focused tests are listed by path in
the upstream record. `python -m tools.ci.native.flutter` runs the vendor suites.

Native desktop microphone selection updates `Hardware.selectedAudioInput` only
after FlutterWebRTC confirms the OS route switch. If native selection fails,
the SDK cache stays on the previous device, matching the application and room
options after their rollback.
