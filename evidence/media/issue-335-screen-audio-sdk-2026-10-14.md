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

## Final-source build and delivery checkpoint

Fix commit: `936fa2282e61272e6b4abc517b939b387462083e`.
macOS 1.0.42 (77) was rebuilt with Flutter 3.47.7 / Dart 3.13.5 and the shared
`macos-direct-stable-r56` identity. Signature inspection passed (ad-hoc), both
architectures are present and the distribution manifest reports this exact
source with `source_dirty=false`. Every embedded SDK executable `__TEXT`
section matches the downloaded public r2 framework; its revision marker is
present. Embedded framework SHA-256:
`20419d9a76e9e2a5ecd0c149778bc602888b9d807ff2af63992935705f2da427`.
The published [macOS ZIP](https://github.com/Egkurilov/BOOHTACORD/releases/tag/macos-v1.0.42)
has SHA-256 `623af9ffc5c3033f2b562e5bddf8f306b7d0605c1825090a3d546dd8e820bea1`,
confirmed by the GitHub asset digest. Manifest/checksums/component notices are
attached. The final client is open at login; physical smoke remains NOT_RUN.

The iOS arm64 unsigned device archive also passed on Flutter 3.47.7 with the
TestFlight/beta identity. 1353 relevant runtime source files were compared with
the fix commit; only the three documented local signing/bundle packaging
overlays differ. Host and ReplayKit extension both have 1.0.42 (77), with a
matching extension selector. IPA/TestFlight remain BLOCKED by the missing
App Group parent and extension distribution profiles; features were retained.

Build server [38482998048](https://github.com/Egkurilov/BOOHTACORD/actions/runs/38482998048)
and production deployment [38484288236](https://github.com/Egkurilov/BOOHTACORD/actions/runs/38484288236)
passed for the fix source, rebuilding and deploying API/Web through the existing
signed bundle workflow. Android's required Flutter gate passed; signed packaging
is still in the native signing queue at this checkpoint.

Windows release 38483751676 and the corresponding main-CI Windows gate failed
before app tests when cold Flutter startup made the machine-version output
unparseable. Both Windows workflows now initialize Flutter before requesting
JSON. A separate build recipe in `codex/issue335-sdk` checks out the immutable
fix source and retains the same tests/analyzer/build/publisher; it does not move
the Windows release tag or bypass gates. Its version probe passed and required
tests are running in
[38485185006](https://github.com/Egkurilov/BOOHTACORD/actions/runs/38485185006).

## Release build recovery

Windows run 38485185006 passed its Flutter tests/analyzer, release build,
measured signing inspection, ZIP packaging and artifact retention. Only the
publication step failed because the one-off recipe used the branch name in the
ZIP filename. The retained artifact was downloaded without rebuilding. Its
manifest reports source `936fa2282e61272e6b4abc517b939b387462083e`,
`source_dirty=false`, version 1.0.42+77 and Authenticode `unsigned`. All packaged
file sizes/digests and SHA256SUMS passed verification. The inner distribution
ZIP SHA-256 is `f8928ae5a7db3a31fac4001e5ed5929854a896ec3aef2ae3cc7fc8667647aa9a`.

Android run 38483584503 passed the existing Flutter quality gate, including
Android debug compilation, but signed release compilation failed because
Flutter 3.47.7 omitted dev-only Gradle plugins while the Java registrant left by
`pub get` still referenced `integration_test`. The Android builder's `--no-pub`
flag skipped Flutter's release-mode tooling regeneration. The supported build
command now allows that regeneration after enforced lockfile resolution. The
focused command regression failed before the change and passed afterwards;
nine command/signing boundary tests passed. Fix commit:
`768b7f9ea27f0166bb4ffbf979f1d51a9201ab57`. Application runtime files and native
version are unchanged from the SDK/audio fix. The immutable Android tag is
retained; a clean checkout of this build-command commit explicitly records its
true source in the APK manifest. The original Flutter quality result is reused
for unchanged app sources; no additional simulation or device matrix is run.
Signed rebuild run: [38487779735](https://github.com/Egkurilov/BOOHTACORD/actions/runs/38487779735).

Follow-up backend/Web build 38486317671 and deployment 38487492666 also passed
at source 4791b7f5f58efe3c600fe2b5f963d30679a95fd1. Main CI for that source was
cancelled by the subsequent Android-command commit, not reported as PASS.
Physical audible smoke remains NOT_RUN and #335 remains open. The rebuilt final
macOS client is still at login. No credential entry or audible result is inferred.

## Completed publication

[Android 1.0.42](https://github.com/Egkurilov/BOOHTACORD/releases/tag/android-v1.0.42):
run 38487779735 passed. All three APKs passed actual apksigner verification,
application/version/ABI version-code inspection, signer continuity and size
inspection. The downloaded public manifest and SHA256SUMS were verified against
GitHub asset digests; every published asset digest matches the checksums.
Source `768b7f9ea27f0166bb4ffbf979f1d51a9201ab57`, source_dirty=false,
version 1.0.42+77, certificate SHA-256
`394e369de2d566b4897493ee498da2f27745e514c49ca88c6489b0b0a811212b`.
APK sizes: arm64-v8a 20,367,092 bytes; armeabi-v7a 18,233,444; x86_64 21,726,910.
Arm64 APK SHA-256:
`0f8601a296e8130859429b30c2401d53fbc0e12ba3438bdebca0ff4bb10ce2c0`.

[Windows 1.0.42](https://github.com/Egkurilov/BOOHTACORD/releases/tag/windows-v1.0.42):
publication-only recovery run 38489064490 passed without compilation or app-test
repetition. The retained ZIP, manifest and SHA256SUMS are published and all three
GitHub asset digests match the previously verified local artifact. An interrupted
browser upload had left an invisible-to-anonymous starter with the declared full
ZIP size and no digest. Recovery removed only that observed owned ID in starter
state; the completed manifest and all completed releases were preserved.
Signing remains explicitly unsigned. The release tag/source remains 936fa228.

Latest build server run 38487722716 and production deployment 38488760578 passed
at source 768b7f9e, delivering API/Web through the normal immutable bundle.
No simulations, new device matrices or optional load campaigns were initiated
for this request. Existing mandatory CI/release workflows were retained.

Final remaining gaps: iOS distribution provisioning BLOCKED; physical audible
Mac/Web smoke NOT_RUN. These are not reported as passing or used to close #335.
Owned temporary signing keychain was locked and removed from the current search
list without replacing other user keychains; owned plaintext passwords removed.

## iOS distribution provisioning resolved

The replacement App Store profiles supplied on 2026-10-14 were validated and
assigned to the two Release targets in the private iOS packaging checkout. Both
profiles authorize `group.ru.boohtacord.app`, the existing team and the same
Apple Distribution certificate/private key. The old parent profile is no longer
selected. The app remains `ru.boohtacord.app.test`; the embedded extension remains
`ru.boohtacord.app.test.ScreenShareExtension`. No screen-sharing feature was removed.

Signed archive and IPA export: PASS, Flutter 3.47.7, version 1.0.42 (77),
TestFlight/beta/r56 identity, runtime source 936fa228. Strict codesign verification
passed for the exported app and extension. Actual embedded profile UUIDs,
application identifiers, App Group entitlements, certificate digests and both
version/build values matched the expected replacement profiles.
IPA bytes: 34,508,630. SHA-256:
`c3f97db758f22801408661df441f2920add94a6d53323818fea526ae5ec0b794`.
The signed IPA and verification receipt are retained locally; certificates,
profiles, private signing material and generated binaries are excluded from Git.

TestFlight upload is BLOCKED at this checkpoint: Xcode `exportArchive` with
destination upload returned `Failed to Use Accounts` for the existing team.
The current browser App Store Connect session is also expired. Local sign-in
and 2FA were requested; the signing/provisioning blocker itself is resolved.
No Transporter software license was accepted by the agent. Physical audible
Mac/Web smoke and #335 closure remain pending independently.
