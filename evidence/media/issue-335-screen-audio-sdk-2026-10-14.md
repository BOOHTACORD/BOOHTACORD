# #335: custom screen-audio routing and 10 ms PCM

Scope: T-036 and GitHub #335. Base master:
`bde67d551fefb9cbfea6e5093bd2e091f1a00032`.
Final integration base: `4b7f577f5732c7e7af86bdf602721a470c705450`.
Native client: `1.0.42+77`, release identity order 56.
The existing Flutter 3.47.7 and m150.7871.03 upgrade is preserved. Dart is
aligned to its actual bundled version, 3.13.5.
Only focused native/unit tests and builds were run; no race simulation,
synthetic load, FPS/codec matrix, emulator or full screen-sharing acceptance.

## Implementation and native delivery

The initial control SDK used `030ad13afd0ab7d16c70662e0e793ea1b892c158`.
The final SDK preserves current master source
`0385653a83f21acf3c916466d4088b29fe2f160b`; both were actually patched,
built for arm64 and x86_64 and linked into the ordinary macOS Release app.
The SDK routing patch covers source classification through the sender adapter,
voice engine and send-stream configuration; custom streams avoid AudioState
registration in Start, Stop and StoreEncoderProperties. A type change stops
under the old type, reconfigures and restarts under the new type.
Runtime serialization checks were not removed.

The macOS-only `BOOHTACORD_WEBRTC_CUSTOM_SOURCE_ROUTING` define enables the
matching appended virtual method in the Darwin shim. Its screen source returns
`kCustom`; iOS/Android retain the existing ABI and SDK pins. The app strongly
links the SDK's public revision marker, so the old framework cannot satisfy
the new interface. There is one macOS WebRTC dependency shared with LiveKit.

PCM retains actual integral sample rate and mono/stereo channel order. The
bounded source accumulates and splits exact 10 ms blocks, carries less than
one block and clears residuals on format change, final sink removal and stop.
Synchronous sink delivery owns its samples; existing producer/stop/removal
fences and capture generations remain. Unsupported SCK formats fail explicitly.
The existing callback-driven pacing, microphone processing and video policy
are preserved.

## Focused test evidence

| Check | Result |
|---|---|
| Real ScreenAudioSource framing regression against old implementation | RED: wrong block length |
| Production ScreenAudioSource, old ABI and macOS custom ABI | PASS |
| 48 kHz mono/stereo inputs 128/256/480/512/960/1024/2048 frames | PASS: 480 frames/channel, sample order, bounded residual |
| Format, sink and stop residual/lifetime boundaries | PASS |
| Actual CoreMedia conversion and owned PCM | PASS: mono/stereo, 44.1/48 kHz, fractional-rate and unsupported-channel rejection |
| Fractional-rate converter regression against old implementation | RED: silently truncated rate |
| Multichannel converter regression before channel validation | RED: silently selected two of three channels |
| Rebuilt SDK AudioSendStream tests | PASS: 2 actual AudioState/AudioTransport route tests |
| Flutter capture-policy/version tests | PASS: 24; repeated PASS on Flutter 3.47.7 / Dart 3.13.5 |
| Contract verifier after native identity update | PASS: 19 tests, lint, 108 operations |
| Existing public-header test | PASS: 1 |

The SDK tests use its real-time controller and existing encoder observer. They
are not a copy of the routing algorithm or a race-overlap model. Tests prove
custom exclusion after encoder updates and preservation of ADM microphone
delivery across source changes. They do not establish physical audio playback.

## Rebuilt artifacts at the local checkpoint

- Go API build: PASS, pinned Go 1.26.4, CGO disabled.
- Web production build: PASS, pinned Node 24.18.0 and production public origin.
- macOS ordinary Release: PASS, pinned Flutter 3.47.5, no capture-engine define.
  The embedded framework exports the routing marker; all measured executable
  `__TEXT` sections match the locally rebuilt SDK. Embedded binary SHA-256:
  `1239923c5363fed8909f5cb1863ac77eae30dd5b350ed7c7b4d5f82f58d8d4d9`.
  The packaged control candidate is ad-hoc signed and not notarized.
- A fresh local SDK assembled by the retained recipe has archive SHA-256
  `f1bcf803c8c3c079cff5a731445bfd30f8842ca08dd145d17c27ebc928270c1e`.
  The actual load commands require macOS 11.0 on arm64 and 10.15 on x86_64,
  preserving the Intel deployment floor. Its receipts are local build evidence,
  not a checksum for a future CI-produced archive.
- iOS device archive: PASS, unsigned, host and ReplayKit extension both
  `1.0.42 (77)` and the host extension selector matches the embedded extension.
  Signed IPA/TestFlight: BLOCKED. The available App Store parent profile has
  no App Group; an App Store profile for the extension is also missing.
  The existing distribution identity alone cannot sign the required entitlements.
- Signed Android/Windows releases: pending the final published source and
  existing release workflows. Local development signatures are not substituted.

The immutable public SDK pin, final-source client packages and backend/Web
deployment outcomes will be recorded after their actual workflows finish.
Local logs, native test JSON and embedded-section proof are retained in
`.out/issue335/`; generated SDKs, apps, audio/video, credentials and crash
identifiers are excluded from Git.

## Immutable final SDK and release integration

The published final SDK is `webrtc-m150-boohtacord-r2`, archive SHA-256
`0617e131f303f4a76acbdcf4f9538fc1e359fc56e7ba1234f3e8bda40bc23de2`.
Its public download was fetched and verified against the actual source revision,
retained patch digests and native routing result. The delivered binary contains
`m150-038565-custom-source-r2`, both arm64/x86_64, and load-command floors
11.0/10.15 respectively. Raw framework binary SHA-256:
`42fbe770c15691dc75bee85ef6797843940fd3a8a49f90097235e110f15978d2`.
Recipe commit: `18b7313b6378e36bdcd380e1e476e955a0566d1d`. The SDK release
tag is anchored to the integration base; source/build provenance is explicitly
recorded by the recipe and manifest, not inferred from that tag. The earlier
r1 candidate remains immutable and is not the app dependency.

The two focused SDK routing tests passed again on the preserved source revision.
SPM and the shared CocoaPods dependency pin this same r2 archive/checksum.
Per-app compilation of a second local SDK is removed from macOS workflows.
The ordinary app build resolves the verified SPM dependency directly.
Existing native release workflows retain their tests/signing and allow manual
dispatch from the matching tag; macOS uses a hosted runner for the existing
ad-hoc distribution. The workflow verifier passed. Physical notarization or
TestFlight provisioning is not implied by an ad-hoc macOS release.

## Physical smoke

NOT_RUN at this checkpoint: new macOS 1.0.42 is open at login; Web viewer is
authenticated. The pending check is one Mac/Web pair, 1–2 minutes with screen
audio and no microphone publication, microphone/system-audio independence,
three stop/start cycles and a short video-only share. Audible playback must
be observed or reported by the user, not inferred from publication/stats.

#335 remains open until its required basic audible smoke passes. This change
does not close #334 or the screen-sharing epic #326 and its hardware gates.
