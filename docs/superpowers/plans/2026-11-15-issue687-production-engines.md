# Production noise engines implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ordinary Web and Windows builds ship RNNoise 0.2 and DeepFilterNet3,
show actual engine versions, preserve mute/device/fallback behavior, and receive
verified release delivery after required CI.

**Architecture:** Pin complete upstream distributions and model identities.
Prepare source-bound assets in the normal build path; runtime loads only bundled,
hash-verified engines. Reuse current capture hooks, workers and Auto preflight.
Keep Android/macOS processing unchanged. No server-side audio or recording.

**Tech Stack:** Vue/Vite/AudioWorklet/WASM; Flutter/WebRTC/C++/Rust; Python build
verification; GitHub Actions and existing retained-bundle server delivery.

Execution is sequential by the primary agent. No delegation is required. The
executing-plans helper is absent from both installed skill roots; native tests,
explicit packets and source review remain the execution method.

## Operating brief

- workflow_class=split_first; task_size=large; structure_mode=structure_no_rg.
- Source baseline: master 6f3f536d33205d6a5e2a39829924137af4e6e65b.
- Branch: codex/issue687-production-engines. Preserve ignored local artifacts.
- First leaf: tools/audio/release_source; later packets below remain separate.
- Ratchet: target 100/hard 120 lines; target 8/hard 16 files per leaf.
- Complete only after production assets and effective runtime identities pass;
  synthetic processing does not close the entire original speech-quality DoD.

## 1. Source and notice delivery

- [ ] Add tools/audio/release_source/lock.json, verify.py, test_verify.py.
- [ ] Pin official rnnoise-0.2.tar.gz SHA256
  90fce4b00b9ff24c08dbfe31b82ffd43bae383d85c5535676d28b0a2b11c0d37,
  its COPYING SHA256 45d37ca1cdb278c088e1aa85e0e65ca3a534ed86a28dcc96ca16810248a61d35,
  packaged model C dece58eabca6a722a0bd9dbc8dfadba27abac1271760fad65e1071f54717dc78.
- [ ] Record that this official source archive contains weights and COPYING;
  do not silently relabel the different research model 522b6a64 as this model.
- [ ] Read pinned DeepFilter LICENSE/MIT/APACHE and model archive notices;
  retain transitive notices and fail on missing notices.
- [ ] Test corruption before extraction and bounded safe extraction:
  `pytest tools/audio/release_source -q`.

## 2. RNNoise production library and WASM

- [ ] Add common/rnnoise/release_v02/library.cmake and nearest CTest;
  bind it from clients/flutter/packages/flutter_webrtc/common/rnnoise/CMakeLists.txt
  only for Windows; preserve current Android/macOS path and research fixtures.
- [ ] Use existing v0.2 ABI bridge and processing tests with the official source;
  build without a research marker and expose the actual model hash/version.
- [ ] Add tools/audio/release_rnnoise build and tests using pinned Emscripten;
  run native CTest and quality_harness against the produced WASM.

## 3. DeepFilter production assets

- [ ] Add tools/audio/release_deepfilter source/build/notice leaves using existing
  pinned native/Web preparation code without the allocation counter.
- [ ] Preserve checked C ABI, catch panics with unwind, validate pointer/count,
  finite output and lifetime. Compile preparation outside the audio callback.
- [ ] Verify repeated source builds and complete notices; run safe FFI and
  existing worker/overload/reset tests before packaging.
- [ ] Normal tools/build/windows/run.py prepares/bundles the model, DLL and
  expected hashes. Default production flags expose the bundled engine.

## 4. Ordinary Web build

- [ ] Update clients/web/scripts/deepfilter_assets.mjs and research_asset_guard.mjs
  to accept verified production manifests while rejecting research-only assets.
- [ ] Integrate reproducible asset preparation with the normal Web/Docker build.
- [ ] Update rnnoise_model.ts and capabilities.ts defaults; verify required
  assets, same-origin loads, cancellation, timeout and fallback tests.
- [ ] `npm --prefix clients/web run build` must contain both engines without
  VITE experimental opt-ins; missing/tampered production assets must fail.

## 5. Versioned settings and runtime identity

- [ ] Web: NoiseSuppressionSelect.vue, noise_suppression_status.ts and their
  exact tests show RNNoise 0.2 / DeepFilterNet3 and effective model identity.
- [ ] Flutter: widgets/noise_suppression_selector.dart, details.dart and settings.dart,
  services/native_noise_suppression_state.dart and native_noise_state_read.dart;
  add model identity from native capabilities, never a hard-coded v0.1 label.
- [ ] Add focused failing Web/Flutter tests before these changes. Preserve stored
  off/browser/rnnoise preferences; explicit OFF and mute must never enable NS.
- [ ] Update voice-audio-processing/shell-navigation-parity scenarios in
  tools/qa/local_features/features.json; inspect native/browser screenshots.

## 6. Acceptance and CI

- [ ] Run focused type/unit/native/asset tests and default release builds.
- [ ] Exercise production engine code on isolated LiveKit with two independent
  clients: received audio, engine/model identity, switch, mute/deafen, reconnect,
  fallback, device settings and bounded stability; do not save microphone PCM.
- [ ] Run canonical local feature gates and preserve any NOT_RUN/BLOCKED result.
- [ ] Add ordinary-build asset checks to required CI; review source-bound outputs.

## 7. Merge, release and actual delivery

- [ ] Update build identity for unused Windows 1.0.56+92/r71 and Web 1.0.56/r64
  after checking remote tags; retain source-bound model manifests and notices.
- [ ] Open/attach PR, require green exact-head checks, merge without bypass.
- [ ] Wait green master, publish Windows through exact-tag native flow, validate
  public assets and actual default configuration; deploy Web trusted bundle.
- [ ] Promote verified catalogs, verify live receipt/images/versions/URLs and
  restore automatic delivery if temporarily held. Update #687 with actual gates.
