# WebRTC-SDK patch: custom screen-audio routing

`webrtc-sdk-m150-custom-source-routing.patch` is the source-routing subset of [webrtc-sdk/webrtc#292](https://github.com/webrtc-sdk/webrtc/pull/292), draft PR revision `f485a890404fc19189217c6cb00b88309b9f6d6f`. It adds `AudioSourceInterface::SourceType`, carries that value through the sender adapter, and skips `AudioState` / ADM registration for custom-fed streams. The default remains the ADM path, so existing microphone tracks keep their route. The subset excludes the PR's new general-purpose `CustomAudioSource` API.

The matching app-side change is integrated: the local WebRTC interface shim gains the same enum and `ScreenAudioSource` identifies itself as `kCustom`. It is guarded by `BOOHTACORD_WEBRTC_CUSTOM_SOURCE_ROUTING`, defined only by the macOS SwiftPM target that links the patched framework. iOS and legacy CocoaPods still use their existing binary and vtable.

## Build and install for macOS

From the repository root:

```sh
python3 tools/build/webrtc_sdk/build_macos.py --test
cd clients/flutter
flutter run -d macos --dart-define=BOOHTACORD_MACOS_CAPTURE_ENGINE=screen_capture_kit
```

`../apple-sdk.json` pins the m150.7871.03 source revision and depot_tools. The builder applies the routing and regression-test patches, runs `AudioSendStreamTest.*` when requested, builds arm64 and x64, and installs the universal local XCFramework in `macos/flutter_webrtc/Binary/`. The generated `sdk.json` records the source, patches, binary SHA-256 and UUIDs. Source and build caches live in `.out/webrtc-sdk/`; generated binaries stay out of Git. macOS CI uses the same builder and caches the installed SDK by the manifest, patches and build script.

The regression tests inject ADM frames into a custom stream before and after a codec change and stop/start, verify that only explicit custom frames are encoded, and verify that default device streams still receive ADM frames after restart. `replaceTrack` in both directions and physical system-audio/peer playback with the microphone disabled remain acceptance requirements; unit tests and application startup alone do not close them.

This local SDK is `150.7871.03-boohtacord.1`. It has not been published as an upstream WebRTC-SDK release. A future iOS/CocoaPods integration must switch its binaries and source-type compile flag together. The original crash framework UUID was `D58568C4-76D7-34BD-ACBD-B5BD55900541`; retaining that binary with the new unguarded vtable would be unsafe.

