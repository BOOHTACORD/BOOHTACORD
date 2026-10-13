# macOS screen-audio crash: WebRTC ADM/custom-source race

**Status:** `NOT_RUN` — source patch prepared; rebuilt SDK, native reproduction, and peer playback acceptance remain outstanding.

## Evidence and diagnosis

- The supplied macOS crash terminates in `AudioSendStream`'s serialized-capture check while the caller is `ScreenAudioSource::CaptureFrame` on `boohtacord.sck.audio`.
- The BOOHTACORD source already serializes ScreenCaptureKit delivery in `ScreenAudioSource::CaptureFrame`; its options also set `init_recording_on_send = false`. That does not classify the source for WebRTC's sender routing.
- In WebRTC m150, `AudioSendStream::Start()` registers every active send stream with `AudioState`; `AudioTransportImpl::SendProcessedData()` fans ADM capture frames out to those registered senders. A custom ScreenCaptureKit callback can therefore overlap ADM delivery into the same sender. The crash report has no second callback stack, so it does not identify which device callback overlapped; the SDK routing mismatch is the supported root-cause hypothesis.
- WebRTC-SDK draft PR [#292](https://github.com/webrtc-sdk/webrtc/pull/292) addresses this exact structure by propagating a source type and keeping custom sources out of ADM fan-out. The focused SDK patch and app-side adapter patch are in `clients/flutter/packages/flutter_webrtc/third_party/patches/`.
- The report says the microphone was not published. No microphone-specific cause is inferred.

## Not yet proven

- The SDK patch has not been applied to a WebRTC source checkout or built. The matching source tree and build configuration are not vendored here.
- The app-side patch must wait for a rebuilt Apple framework containing the source-type routing change. Current CocoaPods and SwiftPM pins remain `150.7871.01`.
- No physical macOS test with ScreenCaptureKit system audio, microphone disabled, remote playback, and sender stop/restart has run against a patched framework. Keep crash-fix acceptance `NOT_RUN` until that evidence exists.

