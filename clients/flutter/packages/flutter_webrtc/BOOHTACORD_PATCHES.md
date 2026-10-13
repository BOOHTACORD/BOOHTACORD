# BOOHTACORD patches

This local fork is based on `flutter_webrtc 1.6.2+hotfix.3`. Keep these changes
when rebasing or restoring the package from pub.dev.

## macOS lazy factory readiness

`ensurePeerConnectionFactoryReady` now exercises the Mac lazy ADM path with an
empty local PeerConnection, then closes and disposes it before readiness. Normal
initialize alone is insufficient. No Room, SDP, ICE servers, tracks or capture
are created. Single-flight success and retryable failure are covered at the real
MethodChannel boundary in `test/unit/macos_factory_readiness_test.dart`.
Other platforms keep their prior initialization. See ADR025; physical Mac QA184
remains required for actual endpoint inventory, privacy, hotplug and selection.

## Android MediaProjection track settings

`GetUserMediaImpl.getDisplayMedia` includes the actual display width, height,
and capture frame-rate in the created track's `settings` map. The selected
profile's longest edge and frame-rate ceiling are separately passed to the
MediaProjection capturer so capture output can be bounded without treating the
physical display size as an app-only source size.

On Android 14+, `OrientationAwareScreenCapturer` also honors
`MediaProjection.Callback.onCapturedContentResize`. App-only capture can have
dimensions and aspect ratio different from the physical display; those content
dimensions now resize the virtual display and are not rotated to match the
device panel. Legacy/full-display capture keeps the existing orientation
normalization until MediaProjection reports authoritative content dimensions.
Unit coverage is recorded in
[QA-184](../../../../evidence/flutter/qa184-android-app-window-capture-resize-2026-10-01-001.json).

Android screen-share profiles now pass their longer edge and frame-rate ceiling
into the MediaProjection capturer. The virtual display is bounded to that edge
for both full-display and app-only resize callbacks, preserving aspect ratio;
frames above the selected cadence are gated before reaching the WebRTC video
source. This reduces downstream frame processing, but does not claim to lower
MediaProjection compositor cadence or device thermal load. Android profile
changes require a fresh user-started capture. Physical low/high, orientation,
background, OS-stop, receiver and long-run checks remain open.

The related LiveKit encoding support and Flutter profile logic live in
`clients/flutter/packages/livekit_client` and `clients/flutter/lib/src/services/screen_share_quality.dart`.
See [QA-88](../../../../evidence/flutter/qa88-android-screen-share-resolution-cap-2026-09-29-001.json).

## macOS ScreenCaptureKit screen profile

The macOS 13+ full-display capture path reads the requested width/height
profile, caps ScreenCaptureKit's output by its longer edge, and rounds both
output edges down to even pixels. It preserves the selected display's aspect
ratio instead of forcing a 16:9 buffer. The custom window-source and macOS 12
fallback paths use the frame processor described below; physical runtime
acceptance remains open.

## macOS legacy and window screen profile

`FlutterScreenShareResolutionProcessor` applies the selected maximum long edge
to each captured frame before it enters the WebRTC video source. It preserves
frame aspect ratio, rounds output edges down to even pixels, and leaves frames
already within the profile untouched. This covers custom window capture and
the pre-macOS-13 screen fallback; physical source/profile acceptance remains
open.

## Android encoder dimension changes

The Android stream encoder wrapper now compares both input frame dimensions
with the encoder's configured dimensions before passing a frame through. A
height-only change (for example, during a portrait/landscape resize with a
stable width) is adapted to the full configured frame instead of being encoded
at a stale height. JVM tests cover matching dimensions and independent width
and height changes; real-peer crop acceptance remains open.

## MediaProjection stop propagation

The Android capturer forwards the OS `MediaProjection.Callback.onStop` event to
the Dart track-ended dispatcher. The Dart dispatcher buffers an early native
event until LiveKit attaches its `onEnded` callback and delivers it at most
once. This allows a system-level stop to unpublish the local screen track.
Physical Android receiver and OS-stop acceptance remain open; see [QA-26](../../../../evidence/flutter/qa26-android-media-projection-service-2026-09-27-001.json).
The capturer also emits low-frequency, content-free log events for projection
start, captured-content visibility changes, OS stop and normal app teardown to
support diagnosis of app-only blanking versus capture termination — [QA-208](../../../../evidence/flutter/qa208-android-projection-diagnostic-events-2026-10-02-001.json).

## Desktop source thumbnail race

The native desktop capturer can emit a source preview while the asynchronous
`getSources` method response is still pending. Preserve that preview when
merging the response snapshot so callers can use its JPEG dimensions before
publishing. The ordering regression is covered by
`test/desktop_capturer_thumbnail_test.dart`.

## Desktop screen-capture start failure

`FlutterScreenCapture::GetDisplayMedia` checks the native capturer's start
state. When it returns `CS_FAILED`, the plugin removes the unpublished video
track/stream and any loopback-audio track, stops loopback capture, and rejects
the method call so Flutter cannot publish a healthy-looking but permanently
black track. The same rollback now covers stale/missing sources and video
capturer/source/track creation failures after this request started loopback
audio; it does not stop an unrelated active capture. Flutter displays the
native error message rather than the `PlatformException` wrapper. Windows
compilation passes, while injected-failure runtime and window-source
acceptance remain open; see [QA-98](../../../../evidence/flutter/qa98-windows-screen-capture-start-failure-2026-09-29-001.json)
and [QA-103](../../../../evidence/flutter/qa103-desktop-screen-share-rollback-2026-09-29-001.json).

## Windows audio input route failure reporting

The Windows `AudioDeviceModule::SetRecordingDevice` result is checked when
selecting an input. A failed native route change or device enumeration now
returns a generic MethodChannel error instead of reporting success and letting
Flutter persist a device that the ADM rejected. The device-selection result
mapping has a standalone C++ regression test. The Windows plugin CMake target
builds and runs it. Real Windows hardware capture acceptance remains open.

## Native screen-share playback audio

`getDisplayMedia({audio:true})` now returns a separate WebRTC audio track for
screen playback where the platform provides an eligible capture source. The
capture is attached to the existing screen-share stream so LiveKit publishes
it as `screenShareAudio`; it does not use the microphone ADM or combine the
microphone with captured playback.

- Windows uses the existing desktop loopback route. Linux uses the existing
  PulseAudio loopback route and requires the `libpulse` development package at
  build time; the Linux CMake configure warning identifies builds without it.
- Android 10+ uses `AudioPlaybackCapture` and asks for `RECORD_AUDIO` before
  starting MediaProjection. Android and the source app can still deny playback
  capture; that is returned as a capture error instead of a video-only stream.
- macOS 13+ uses ScreenCaptureKit audio capture and excludes BOOHTACORD's own
  process audio. Older macOS versions do not expose this route through the
  current implementation and return no audio track.
- iOS uses ReplayKit app-audio samples. A Broadcast Upload Extension forwards
  bounded JPEG/PCM messages over the existing app-group socket; microphone
  samples are discarded. The user must approve the system broadcast picker.

The shared native WebRTC source accepts bounded signed 16-bit PCM, disables
voice-specific processing on that already-mixed source, and safely waits for
active audio sinks to detach before stopping. iOS socket framing and image/audio
sample sizes are bounded. Runtime acceptance on actual devices and all source
privacy policies is still required; build and unit tests alone do not claim
successful playback capture.

SwiftPM only compiles sources inside each plugin package, so iOS and macOS use
small package-local wrappers for the shared Darwin bridge. CocoaPods excludes
those wrapper files and compiles the shared implementation directly to avoid
duplicate symbols.

## Source and maintenance policy

[UPSTREAM.json](UPSTREAM.json) pins the published upstream archive SHA-256,
license and changed source files, measured against the verified pub.dev archive.
The local overrides remain required. Return to upstream only after the fixes
are included and the focused tests plus affected platform media acceptance pass.

Additional retained patches cover AGP built-in Kotlin compatibility, direct
Android frame buffers and capture serialization, EGL surface-release barriers,
and macOS renderer disposal/first-frame propagation. Their JVM/Dart tests are
listed in the upstream record. The macOS/Darwin texture renderer now emits its
first-frame event only after copying a pixel buffer and notifying Flutter that
the texture frame is available — [QA-206](../../../../evidence/flutter/qa206-macos-texture-first-frame-upload-2026-10-02-001.json). When an RTC video track changes, the renderer also releases a pending texture-frame gate left by the old track; otherwise an unsampled frame could block the new track. This lifecycle regression is covered by [QA-209](../../../../evidence/flutter/qa209-macos-renderer-track-replacement-2026-10-02-001.json). Compilation alone does not certify hardware.

Renderer texture, srcObject and first-frame work is generation-gated so late
native callbacks from an older publication cannot replace the selected viewer.
The Flutter viewer pauses its bounded five-second first-frame deadline while
the app/window is backgrounded, performs at most one automatic subscription
retry per generation, and starts that retry immediately for a matching
`TrackSubscriptionExceptionEvent`. If the retry does not produce a frame, the
viewer exposes an immediate explicit retry action. The subscription lifecycle
rebinds the selected LiveKit track through its normal renderer path.
Focused Flutter/device acceptance remains pending; no hardware behavior is
claimed.

## MW-04 macOS bounded capture diagnostics (#330)

The macOS plugin exposes `mediaStreamTrackGetCaptureSnapshot(trackId)` for local
screen-video tracks. It reports raw accepted and processed RTC-delivered frame
counts/dimensions separately, configured limits only after native start and a
valid current-stream frame, and a session generation. Unknown platforms/tracks
return unavailable; Dart does not infer settings from defaults. Numeric counters
and a 256-sample processing-time ring are session-owned. MethodChannel
serialization runs only on query, never on a per-frame callback. `frame_age_ms`
uses the native monotonic clock since the latest accepted callback; it is not
capture-to-delivery latency. This continuous clock includes time suspended
during sleep, so queued frames do not appear fresh after wake. CoreMedia PTS
remains separate; actual sleep/wake hardware acceptance is still required.
Legacy capture configuration remains unknown.

`video.mandatory.captureEngine` is read once at start: `baseline` retains display
SCK/window RTCDesktopCapturer routes; `screen_capture_kit` selects exact window
or display SCK on macOS 13+. Unknown values and unavailable engines fail with a
bounded error. No active capture changes route. SCK uses the selected window's
desktop-independent filter and fails closed when an explicit source disappears.
Geometry uses filter points and pixel scale on macOS 14+, and matching display
pixel-mode scale on macOS 13; output keeps aspect ratio and even dimensions.
An acknowledged geometry update needs a matching fresh frame to confirm limits.
User quality changes remain explicit restart-required operations.

Native start requires both OS start acknowledgment and the first valid delivered
frame, with a five-second deadline for video with or without playback audio.
Validity, complete-frame status, finite monotonic PTS and stream/session identity
are checked. Video has one processing and one replaceable pending sample, a
100 ms queue-age limit and an OS queue depth of three. Audio runs on a separate
queue and is not subject to the video drop policy. Stop invalidates callbacks
and fences both processing queues before completion. Permission/source errors
end the matching track; no source title/ID or sample content is logged.
Startup error paths remove the unreturned track's stop-handler registry entry
before returning FlutterError, so failed starts cannot retain a capture/source
which the caller has no track ID to dispose.

In-profile buffers remain unchanged. Oversized native CVPixelBuffer frames use
one retained CIContext/color space and a four-buffer output pool; native I420
buffers scale directly without a full-size BGRA roundtrip. Processing/pool
failure drops the frame, never forwards oversized input.
Resized RGB buffers carry explicit sRGB color labels and their current aperture
and display dimensions; source HDR/color/geometry attachments are not copied.
Direct/no-resize buffers retain their original attachments. No HDR capability
is claimed. Snapshot counters distinguish pool requests/first-seen buffers,
resize and pass-through operations;
total heap allocations and capture timestamp latency remain unknown.
`captureDiagnosticsEnabled=false` disables metrics on a new start. Queue timing
required by the video policy remains active; turning off snapshot polling alone
does not disable native metrics.

The focused Objective-C harness is `tools/qa/native_capture_boundary`; physical
capture/performance and independent second-device acceptance remain separate
gates. Package pins, upstream archive hashes, licenses and existing patches are
unchanged.
