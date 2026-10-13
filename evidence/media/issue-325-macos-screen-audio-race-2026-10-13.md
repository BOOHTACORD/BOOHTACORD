# macOS screen-audio crash: WebRTC ADM/custom-source race

**Status:** `NOT_RUN` — source patch prepared; rebuilt SDK, native reproduction, and peer playback acceptance remain outstanding.

## Evidence and diagnosis

- The supplied macOS crash terminates in `AudioSendStream`'s serialized-capture check while the caller is `ScreenAudioSource::CaptureFrame` on `boohtacord.sck.audio`.
- The BOOHTACORD source already serializes ScreenCaptureKit delivery in `ScreenAudioSource::CaptureFrame`; its options also set `init_recording_on_send = false`. That does not classify the source for WebRTC's sender routing.
- In WebRTC m150, `AudioSendStream::Start()` registers every active send stream with `AudioState`; `AudioTransportImpl::SendProcessedData()` fans ADM capture frames out to those registered senders. A custom ScreenCaptureKit callback can therefore overlap ADM delivery into the same sender. The crash report has no second callback stack, so it does not identify which device callback overlapped; the SDK routing mismatch is the supported root-cause hypothesis.
- WebRTC-SDK draft PR [#292](https://github.com/webrtc-sdk/webrtc/pull/292) addresses this exact structure by propagating a source type and keeping custom sources out of ADM fan-out. The focused SDK patch and app-side adapter patch are in `clients/flutter/packages/flutter_webrtc/third_party/patches/`.
- The report says the microphone was not published. No microphone-specific cause is inferred.

## Additional crash report (2026-10-13 23:56 local)

- A second report from the same app build and the same WebRTC binary UUID (`D58568C4-76D7-34BD-ACBD-B5BD55900541`) shows `SIGABRT` from `webrtc_checks_impl::FatalLog` on `com.apple.audio.IOThread.client`. Its stack reaches WebRTC through AVFAudio's `InputAvailable` callback.
- At the same time, the report's `boohtacord.sck.audio` stack is delivering ScreenCaptureKit PCM through `FlutterScreenAudioTrackCapturer::appendPCMData` into `ScreenAudioSource::CaptureFrame` and WebRTC. The capture thread is not the crashing thread, but these concurrent WebRTC audio paths corroborate the sender-routing/race hypothesis from the first report.
- This second report does not include a readable failed-check expression or a symbolized WebRTC frame name. It therefore does not independently prove the precise race-check site or prove that the ADM callback carried microphone input. The user confirmed the microphone was not published.

## Not yet proven

- The SDK patch has not been applied to a WebRTC source checkout or built. The matching source tree and build configuration are not vendored here.
- The app-side patch must wait for a rebuilt Apple framework containing the source-type routing change. Current CocoaPods and SwiftPM pins remain `150.7871.01`.
- No physical macOS test with ScreenCaptureKit system audio, microphone disabled, remote playback, and sender stop/restart has run against a patched framework. Keep crash-fix acceptance `NOT_RUN` until that evidence exists.

