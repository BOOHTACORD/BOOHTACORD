# Android RNNoise state ABI implementation plan

> Execution: inline in this chat, as requested by the owner. Keep the existing release work in progress.

**Goal:** Android can query RNNoise before microphone frames arrive and recover from reset without a Java array-index exception.

**Architecture:** Preserve the legacy native codes OFF=0, WebRTC=1, RNNoise=2, UNKNOWN=3. Append DeepFilter=4 rather than shifting UNKNOWN. Android's existing three selectable engines and Web/Windows defaults stay intact.

**Tech stack:** C++17, Android JNI/Java, Flutter, CMake/CTest, Gradle instrumentation on the connected API-35 emulator.

Operating brief: small_direct implementation packet; leaf is native RNNoise state serialization (T-074, dependencies T-071/T-061). Exact edges are rnnoise_capture_processor.h -> rnnoise_capture_jni.cc -> RnnoiseCaptureAdapter.state -> Flutter native_noise_prepare.dart. Target 100/hard 120 lines; no aggregate refactor. Stop when the regression fails before, passes after through actual JNI, focused native checks pass and the patch is source-bound in CI.

## 1. Failing regression

- [ ] Add assertions to `common/rnnoise/tests/rnnoise_capture_processor_test.cc` before the first frame:
  ```cpp
  assert(static_cast<int>(processor.EffectiveEngine()) == 3);
  assert(std::string(processor.failure_reason()) == "awaiting-audio");
  ```
- [ ] Build/run existing CMake target `rnnoise_capture_processor_test`; expect failure because the current UNKNOWN code is 4.
- [ ] Add `android/src/androidTest/java/com/cloudwebrtc/webrtc/audio/RnnoiseStateTest.java` using the existing production adapter: request RNNoise, read supported/unknown/awaiting-audio/zero frames, initialize 48 kHz mono, process one 480-sample direct float buffer, confirm active RNNoise, reset and confirm unknown without exception.
- [ ] Add the pinned AndroidX runner dependency to the existing library's Android-test configuration; run `:flutter_webrtc:connectedDebugAndroidTest` on emulator-5560. Preserve failure output from the unmodified native enum.

## 2. Compatible native codes

- [ ] Replace the implicit enum in `common/rnnoise/rnnoise_capture_processor.h` with:
  ```cpp
  enum class Engine { kOff = 0, kBrowser = 1, kRnnoise = 2,
                      kUnknown = 3, kDeepFilter = 4 };
  ```
- [ ] Re-run CTest and the identical Android instrumentation test. Check pending -> active -> reset -> pending -> active, with real JNI and synthetic PCM; do not describe this as physical microphone/acoustic acceptance.
- [ ] Record this Android regression decision under the existing voice scenario in `tools/qa/local_features/features.json`; invoke the native Android canonical feature runner and retain any unavailable real-stack/visual gate as BLOCKED rather than waiving it.
- [ ] Record the RCA, failed/passed commands and emulator scope in `evidence/noise-suppression/`.

## 3. Patch release and existing delivery

- [ ] Repair explicit product-map ownership of Windows promotion-intent records. PR #793 correctly failed the PR-only new-runtime-path guard; strict master checks require a fresh two-file promotion after the patch merges.
- [ ] Publish Android 1.0.56+92 with native release identity r71. Synchronize shared Flutter metadata and development defaults; this does not replace the already-published Windows/macOS 1.0.55 artifacts.
- [ ] Run client-identity/profile synchronization and contract checks, source CI and master builds; merge the reviewed patch.
- [ ] Use the official exact-master tag/release workflows for Android 1.0.56, preserving the withdrawn immutable android-v1.0.55 tag/assets.
- [ ] Verify downloaded APKs/checksums/source/signer. Promote only the corrected Android release plus independently verified macOS 1.0.55 and live Web 1.0.55.
- [ ] Deliver the final catalog once, verify actual production source, image/schema/volume readback, public selectors and login rendering. Restore the prior active automatic-deployment setting.

## 4. Promotion ownership release gate

- [ ] Add failing cases to `tools/product_map/ownership/test_scopes.py`: the real catalog must assign future `deploy/client-updates/promotions/<64 hex>.json` records to `client.update-awareness` and its delivery component; sibling deployment data must remain unclassified. Broad `deploy/` and `deploy/client-updates/` scopes must be rejected.
- [ ] Allow only the existing leaf `deploy/client-updates/promotions/` in `tools/product_map/ownership/scopes.py`, with minimum depth 3.
- [ ] Link a delivery promotion component and that exact owned root in `product-map/features/updates/core.yaml`; preserve UNKNOWN implementation states.
- [ ] Run `python -m unittest tools.product_map.ownership.test_scopes tools.product_map.ownership.test_new_paths tools.product_map.ownership.test_coverage` before/after; then regenerate and check the tracked product-map viewer using `python -m tools.product_map generate` and `generate --check`.
