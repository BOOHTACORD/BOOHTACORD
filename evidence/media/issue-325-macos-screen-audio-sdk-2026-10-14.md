# macOS custom screen-audio SDK integration

**Leaf:** T-038 (#325), dependencies T-034/T-036.
**Status:** SDK/build/startup `PASS`; physical media acceptance `NOT_RUN`; visual review `BLOCKED` while the Mac is locked.

## Integrated SDK

- macOS SwiftPM now uses locally built WebRTC `150.7871.03-boohtacord.1`, source revision `0385653a83f21acf3c916466d4088b29fe2f160b` plus the focused source-routing patch from upstream PR #292.
- The builder pins depot_tools `2fd34a8813b6f34336aad40976cc4223768177f8`, applies the native regression tests, produces arm64/x86_64 and installs the universal XCFramework. Generated sources and binaries are excluded from Git. CI builds/cache keys use the same source, patches and builder; installed SDK verification checks input revisions, patch hashes and binary SHA-256.
- `ScreenAudioSource` reports `kCustom`. The matching vtable extension is compiled only with the patched macOS SwiftPM framework via `BOOHTACORD_WEBRTC_CUSTOM_SOURCE_ROUTING=1`. iOS and legacy CocoaPods retain the prior interface and SDK pins.
- Xcode 27's TAPI files include `arm64e.x1`, unsupported by m150's LLD. The final configuration uses Apple's linker (`use_lld=false`); both SDK slices build successfully. Capture serialization and race checks remain enabled.

Universal SDK binary SHA-256: `8881a13d2c16b01eab7fee13357adcf4e0ff0bd3f79baa57f00224d894e935b4`.

| Slice | SDK and embedded app WebRTC UUID |
| --- | --- |
| arm64 | `63EB6CFC-B11D-39D9-B05A-E98DE079850C` |
| x86_64 | `E9C56678-006A-3637-B292-1DA4F8DC9C51` |

These differ from the original crash framework UUID `D58568C4-76D7-34BD-ACBD-B5BD55900541`. The macOS plugin's emitted C++ compiler arguments include the matching source-type define, and SwiftPM resolves the installed local XCFramework.

## Observed validation

Host: macOS 26.6.1 / Xcode 27.0 (27A266a). User-upgraded Flutter 3.47.7 / Dart 3.13.5 and its dependency lock are retained; central Flutter/CI pins agree.

| Check | Result | Evidence |
| --- | --- | --- |
| `AudioSendStreamTest.*` against patched SDK | `PASS`, 35 tests, zero failures/errors/disabled | `.out/webrtc-sdk/audio-send-stream-tests.json` |
| Custom stream excludes ADM before/after codec change and stop/start; direct frames still encode | `PASS` | `CustomSourceExcludesAdmAcrossCodecChangeAndRestart` |
| Default device stream receives ADM after restart | `PASS` | `DeviceSourceKeepsAdmAcrossRestart` |
| C++ screen source classification, PCM delivery, volume, stop and reentrant sink removal | `PASS` | `.out/webrtc-sdk/screen_audio_source_test` (classification failed to compile before the interface change) |
| Flutter capture-engine options with requested define | `PASS`, 3 tests | `test/screen_scope/native_screen_capture_options_test.dart` |
| Complete Flutter app unit suite on upgraded toolchain | `PASS`, 1352 tests; one skipped | `.out/webrtc-sdk/flutter-tests.log` |
| Local-feature policy/public-header/toolchain tests and workflow policy | `PASS` | native/public-header policy and committed toolchain/workflow checks |
| Patched universal SDK verification and debug app build | `PASS` | `.out/webrtc-sdk/sdk.json`, `build.log`, `app-build.log` |
| Fresh app process with requested define | `PASS` for startup | `.out/webrtc-sdk/app-run.log`: build succeeds, files sync, Dart VM service starts; no lost connection/fatal check observed at startup |
| Native window screenshot review | `BLOCKED` | Computer-use observation reports a locked Mac; manual unlock requested |

Launch command:

```sh
flutter run -d macos --no-pub --dart-define=BOOHTACORD_MACOS_CAPTURE_ENGINE=screen_capture_kit
```

## Remaining media acceptance

Actual ScreenCaptureKit system-audio delivery with the microphone unpublished, audible peer playback, long-running capture, stop/restart and `replaceTrack` in both directions remain `NOT_RUN` against this binary. Application startup and unit tests do not prove physical capture/peer playback or close the crash-fix release gate. Intel runtime acceptance is also `NOT_RUN`; its framework slice was cross-built on Apple Silicon.
