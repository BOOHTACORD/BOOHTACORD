# WebRTC-SDK patch: custom screen-audio routing

`webrtc-sdk-m150-custom-source-routing.patch` is the source-routing subset of [webrtc-sdk/webrtc#292](https://github.com/webrtc-sdk/webrtc/pull/292), draft PR revision `f485a890404fc19189217c6cb00b88309b9f6d6f`. It adds `AudioSourceInterface::SourceType`, carries that value through the sender adapter, and skips `AudioState` / ADM registration for custom-fed streams. The default remains the ADM path, so existing microphone tracks keep their route. The subset excludes the PR's new general-purpose `CustomAudioSource` API.

`webrtc-sdk-m150-custom-source-regression.patch` adds two focused SDK tests using the real AudioState/AudioTransport/send-stream path. They check exclusion after an encoder update and restoration of microphone delivery across source-type changes. They are not a race simulation or physical playback evidence.

The integrated app-side change extends the Darwin interface shim and returns `kCustom` only when `BOOHTACORD_WEBRTC_CUSTOM_SOURCE_ROUTING` is defined by the macOS plugin. iOS and Android retain their original SDK ABI. The earlier unguarded app-side sketch was removed; it must not be applied to the old iOS framework.

## Apply and release order

1. Build pinned source `0385653a83f21acf3c916466d4088b29fe2f160b` with both retained SDK patches using `tools/build/webrtc_macos/recipe.json` and `run.py`.
2. Publish a new immutable macOS-only XCFramework with architecture receipts, routing-test results and SHA-256 checksum. Existing upstream SDK assets remain unchanged.
3. Pin that same macOS binary in Swift Package Manager and the shared `BoohtacordWebRTC` CocoaPods dependency. Keep iOS manifests and the macro-disabled Darwin interface unchanged.
4. Build the ordinary release. Its strong link to `BoohtacordScreenAudioRoutingRevision` rejects the old SDK. Inspect the embedded framework, then record the short physical Mac/Web smoke and audible playback separately.

The original crash used upstream `WebRTC-SDK` `150.7871.01`, before the routing patch. The new macOS SDK has a public source-revision marker; the app shim and this binary form one ABI change. Runtime race checks remain enabled. Build/unit success alone cannot close #335. See `docs/runbooks/macos-screen-audio-sdk.md` and its evidence record for delivery and physical acceptance status.

