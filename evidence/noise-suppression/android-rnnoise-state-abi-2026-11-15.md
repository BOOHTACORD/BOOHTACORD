# Android RNNoise pending-state ABI regression

The owner reported RNNoise unavailable while the voice connection remained up.
The expanded details reported the standard WebRTC fallback and zero frames.
This is a native state-serialization regression, not acoustic quality evidence.

Shared C++ Engine previously encoded UNKNOWN as 3. Adding DeepFilter before it
implicitly changed UNKNOWN to 4, while Android RnnoiseCaptureAdapter.state still
indexed its four-element OFF/WebRTC/RNNoise/UNKNOWN table. Selecting RNNoise
resets the DSP to awaiting-audio, whose effective engine is UNKNOWN; querying it
throws before a microphone frame is needed. Dart catches the failed method call
and selects the standard fallback, displaying the reported unavailable message.

The fix assigns the legacy codes explicitly (0,1,2,3) and appends DeepFilter=4.
Android selectable modes, the standard fallback, AEC/AGC, model flags and source
weights are unchanged. Windows/macOS serialize names through NoiseEngineName;
their released 1.0.55 packages are not replaced. Web has no implementation change.

## Failed before / passed after

- Native CMake Release rnnoise_capture_processor_test failed before the fix:
  assertion `static_cast<int>(processor.EffectiveEngine()) == 3`.
- Gradle `:flutter_webrtc:connectedDebugAndroidTest`, class
  `com.cloudwebrtc.webrtc.audio.RnnoiseStateTest`, failed before the fix on the
  real API-35 x86_64 BOOHTACORD_QA_ISSUE689 emulator with
  `ArrayIndexOutOfBoundsException: length=4; index=4`, production adapter line 72.
- The identical JNI instrumentation test passed after the fix (one test,
  Gradle BUILD SUCCESSFUL). It loads the real packaged shared library, confirms
  pending/awaiting-audio with zero frames, processes a synthetic 480-sample
  48 kHz mono direct float buffer, confirms RNNoise, resets and processes again.
  It also confirms the standard mode and the unsupported DeepFilter request.
- All 25 native CTest tests passed on the Windows MSVC x64 host, including
  RNNoise, microphone controls, DeepFilter hooks, worker and lifecycle tests.
- Three client-identity tests, the unchanged Flutter profile/package-version
  synchronization test, client parity and 26 contract tests passed. OpenAPI
  lint/parity passed for 137 public operations and four private exclusions.

Logs are retained locally under .out/android-jni-before.log,
.out/android-jni-after.log and .out/rnnoise-abi-after.log. This direct JNI test
does not request microphone permission, capture speech, publish media or prove
physical-device/AEC/AGC/acoustic acceptance. Those broader gates remain NOT_RUN.
Canonical report .out/local-features/20261115-004308 is FAIL: native real-stack
stages cannot start because a local Linux Docker daemon is unavailable. It is
not a passing native application/SFU gate. Flutter unit tests passed 1,991 with
three skips (BLOCKED); component tests passed 872 with one skip (BLOCKED).
Source stability is PASS. Three source-resolution captures (320-wide scale-2
audio, 1440-wide scale-1 audio, 390-wide scale-2 profile with IME) were reviewed:
large text wraps, short fixture viewports clip vertically, and the profile name
wraps. They are byte-identical to prior captures. They do not show a live RNNoise
status or the version label; no broad visual acceptance/baseline is approved.
Other captures remain unreviewed. The unchanged focused profile test covers the
version label. Native header SHA256 after the passing direct JNI/CTest checks:
3d50f3ada403b61077f6b277daa8dc95ecda33eef171faecccf75c444c4a1953.

## Release handling

Android 1.0.55 completed publication during diagnosis. Its immutable assets/tag
are preserved, its release is marked prerelease with the known regression, and
it is withheld from stable catalog promotion. Prepare Android 1.0.56+92/r71 via
the official exact-master release flow after CI. Shared Flutter metadata and
development defaults remain consistent; this does not republish other native
platforms. The full issue 687 acoustic/adaptation DoD remains open.
