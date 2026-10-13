# macOS custom screen audio (#335)

The ordinary macOS client uses the rebuilt WebRTC SDK with the existing
ScreenCaptureKit adapter. The SDK source is pinned to
`0385653a83f21acf3c916466d4088b29fe2f160b`; the two retained SDK patches supply
source routing and focused native regressions. The archive version, compiler
arguments and checksums are retained in `sdk-manifest.json` in its GitHub release.
Existing upstream release assets are never replaced.

`AudioSourceInterface::source_type` is forwarded through the local sink adapter
and voice engine into the send-stream configuration. Custom streams do not
register with AudioState on start, stop or encoder updates. Source-type changes
stop under the previous type and restart under the new type. Microphone sources
keep device audio delivery. Runtime race checks remain in the SDK.

The macOS plugin defines `BOOHTACORD_WEBRTC_CUSTOM_SOURCE_ROUTING=1` and its
screen-audio source reports `kCustom`. A strong link to
`BoohtacordScreenAudioRoutingRevision` prevents linking this new interface to the
old framework. The first screen-audio track logs only the public SDK routing
revision. iOS and Android do not define this macro and retain their original
SDK interface; the Darwin virtual-table extension is isolated to macOS.

PCM conversion preserves the actual integral sample rate and mono/stereo
channels; additional source channels are explicitly rejected instead of silently
selecting the first two. The existing source delivers exactly `sampleRate / 100` frames per
channel; at 48 kHz that is 480 frames, 960 interleaved stereo samples, 1920 bytes.
Short inputs accumulate and large inputs split. The retained residual is less
than one block and is cleared on format change, final sink removal and stop.
Complete blocks own their memory during synchronous delivery. Existing producer
serialization and removal/stop fences remain in force; no new pacing queue,
resampling or per-callback silence is introduced. Unsupported SCK PCM is a
bounded capture failure rather than a successful silent track.

The standard project uses Swift Package Manager and LiveKit imports its one
WebRTC product from `flutter_webrtc`. Both macOS CocoaPods plugin specifications
use the same `BoohtacordWebRTC` dependency. For a CocoaPods project, explicitly
register that local specification in its Podfile before installing plugins:

```ruby
pod 'BoohtacordWebRTC', :podspec => '../packages/flutter_webrtc/macos/BoohtacordWebRTC.podspec'
```

Do not add this to the current SPM project or retain a second `WebRTC-SDK` pod.
The custom specification fetches the immutable macOS-only archive with SHA-256
verification; iOS pins remain unchanged. No system-wide CocoaPods repository or
Flutter setting needs to change.

Rebuild the SDK on macOS with the pinned build recipe:

```sh
python3 -m tools.build.webrtc_macos.run build --arch arm64 --workspace .out/webrtc/sdk --output .out/sdk-inputs/arm64
python3 -m tools.build.webrtc_macos.run build --arch x64 --workspace .out/webrtc/sdk --output .out/sdk-inputs/x64
python3 -m tools.build.webrtc_macos.run assemble --inputs .out/sdk-inputs --output .out/sdk-release
```

Only two real AudioState/AudioTransport/send-stream unit cases run on arm64,
using the SDK's real-time controller. Their encoder sink is an existing test
observer; these tests do not prove physical playback. Unused benchmark media
downloads are omitted. The native Apple linker and unstripped framework retain
valid Mach-O string-table alignment for Xcode 27. Architectures, minimum macOS
versions and the routing marker must be inspected in the delivered framework.

The app-side basic units can be rerun directly from the repository root, without
capturing a screen or running the synthetic SCK boundary suites:

```sh
mkdir -p .out/screen-audio-units
xcrun clang++ -std=c++17 -UNDEBUG -pthread \
  -DBOOHTACORD_WEBRTC_CUSTOM_SOURCE_ROUTING=1 \
  -I clients/flutter/packages/flutter_webrtc/common/darwin/Classes \
  clients/flutter/packages/flutter_webrtc/common/darwin/Classes/ScreenAudioSource.cc \
  clients/flutter/packages/flutter_webrtc/common/cpp/tests/screen_audio_source_test.cc \
  -o .out/screen-audio-units/source
.out/screen-audio-units/source
xcrun clang++ -std=c++17 -UNDEBUG -fobjc-arc \
  -I clients/flutter/packages/flutter_webrtc/common/darwin/Classes \
  tools/qa/native_capture_boundary/pcm_converter_test.mm \
  clients/flutter/packages/flutter_webrtc/common/darwin/Classes/ScreenAudioPCMConverter.mm \
  -framework Foundation -framework CoreMedia -framework AudioToolbox \
  -o .out/screen-audio-units/converter
.out/screen-audio-units/converter
```

Run the source unit once without the macro as well when changing the shared
Darwin code. That checks the original interface retained by iOS/Android.

App build and the explicit capture rollback remain documented in
`macos-screen-capture-default.md`. Basic acceptance for #335 uses one Mac and a
Web viewer: 1–2 minutes of screen audio without a microphone, separate microphone
and system-audio controls, three stop/start cycles and a short video-only share.
Record audible playback separately; unit/build success does not establish it.
Expanded benchmarks, device matrices and the rest of the screen-sharing epic
are outside this fix.

For a distributable macOS release after resolving the locked dependencies,
run `python3 -m tools.build.macos.run` from the repository root. This uses the
same release identity fields as Android/Windows and the default capture engine;
the ordinary development build can still use the documented Flutter command.
