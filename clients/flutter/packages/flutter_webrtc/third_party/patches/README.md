# WebRTC-SDK patch: custom screen-audio routing

`webrtc-sdk-m150-custom-source-routing.patch` is the source-routing subset of [webrtc-sdk/webrtc#292](https://github.com/webrtc-sdk/webrtc/pull/292), draft PR revision `f485a890404fc19189217c6cb00b88309b9f6d6f`. It adds `AudioSourceInterface::SourceType`, carries that value through the sender adapter, and skips `AudioState` / ADM registration for custom-fed streams. The default remains the ADM path, so existing microphone tracks keep their route. The subset excludes the PR's new general-purpose `CustomAudioSource` API.

`boohtacord-screen-audio-source-type.patch` is the matching app-side change: the local WebRTC interface shim gains the same enum and `ScreenAudioSource` identifies itself as `kCustom`.

## Apply and release order

1. Apply the SDK patch to the `webrtc-sdk/webrtc` `m150_release` source tree and add a focused regression test that verifies a custom sender is excluded from ADM fan-out while a microphone sender remains registered. Verify `replaceTrack` in both directions and sender stop/start.
2. Build a new Apple `WebRTC.xcframework` and release it under a new immutable `WebRTC-SDK` version with its checksum.
3. Update all iOS/macOS CocoaPods and Swift Package Manager pins together in `flutter_webrtc` and `livekit_client`.
4. Apply the BOOHTACORD patch, then run the macOS local-feature real-stack scenario with system audio enabled and microphone disabled; inspect the native capture and peer playback. Record the SDK build and device evidence before claiming the crash fixed.

Do not apply the app-side patch against the currently pinned binary. The framework bundled in the supplied crash has UUID `D58568C4-76D7-34BD-ACBD-B5BD55900541`; the workspace's downloaded framework has the same UUID. Current Apple package manifests pin `WebRTC-SDK` `150.7871.01`, released before PR #292. No patched Apple framework is present in this checkout, so the patch is prepared but not yet integrated or validated against the SDK source.

