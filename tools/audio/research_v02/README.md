# RNNoise v0.2 research WASM

This is an isolated comparison probe, not a client engine or release artifact.
The upstream model archive's redistribution license has not been confirmed;
do not bundle the probe or its weights. Use the separate v0.1 release pipeline
for the existing client.

Prepare an external checkout of Xiph commit `904a876dce1f9ab8860c0a5000ed151f9f6eef58`
and obtain `rnnoise_data-0b50c45.tar.gz` from the official Xiph model server.
Before extraction, verify its SHA-256 against `modelArchiveSha256` in
`lock.json`. Extract only after verification. The source and model header hashes
are checked again by the build. `src/os_support.h` must not exist upstream: the
isolated scalar build uses the small local shim instead.

Activate Emscripten 4.0.20 and run from the repository root:

```
python -m tools.audio.research_v02.build_wasm --source <upstream-checkout> --output .out/audio-research/<new-directory>
node tools/audio/quality_harness.mjs --asset-dir .out/audio-research/<new-directory> --lock tools/audio/research_v02/lock.json
python -m tools.audio.research_v02.build_native --source <upstream-checkout> --output .out/audio-research/<new-native-directory> --cmake <cmake-executable>
```

The output directory must not exist and must be under `.out/audio-research`.
For a local opt-in Web probe, set `VITE_RNNOISE_V02_ENABLED=true` and set
`VITE_RNNOISE_V02_WASM_SHA256` to the independently validated SHA-256 of the
research WASM. The loader rejects a missing digest or a manifest with a
different digest. This check is not a publisher signature or permission to
redistribute the model. Remove temporary public assets after the local test.
Production Web builds reject the enabled flag and the presence of the v0.2
public asset directory, even with the flag off; local Vite development is
allowed for isolated research. This guard must not be removed until model
redistribution and release acceptance are established.

For the local-only Web Auto smoke, use the independent research WASM digest as
`VITE_RNNOISE_V02_WASM_SHA256`, set `VITE_RNNOISE_V02_ENABLED=true` and set
`BOOHTA_RESEARCH_ASSET_DIR` to the verified directory containing the v0.2
manifest and WASM. Then run `node node_modules/playwright/cli.js test -c
tests/audio/playwright.auto_v02.config.ts` from `clients/web`. The fixture server
exposes only those two research files and does not place them in public assets.
This scalar probe has no SIMD, runtime dispatch, production integration, release
license clearance, or proof of real-time behavior. SHA matching alone does not
establish perceived quality or source authenticity.
The native `rnnoise_v02_pcm` executable takes an existing mono 48 kHz float32le
input and a new output filename. It pads partial frames and appends 120 ms of
silence, like `tools/audio/speech_fixture/run.mjs`; an existing output is never
overwritten. It is for offline comparisons only, not microphone capture.

To exercise the actual capture processor against the research v0.2 core without
changing the client, run:

```
python -m tools.audio.research_v02.native_adapter.run --source <verified-upstream-checkout> --output .out/audio-research/<new-directory>
```

The local-only CMake targets use an ABI bridge for the changed initialization
signature, run the existing capture processor checks and compare 100 synthetic
48 kHz frames with direct v0.2 calls. A separate experimental target exercises
16 -> 48 -> 16 kHz conversion and safe silence on invalid input or a stale
generation. The ordinary nonexperimental path still rejects 16 kHz. The test
bridge includes a deterministic callback for its stale-generation test only.
It is not integrated into Flutter or a release. A simulated initialization
failure is tested at startup and reset. A failed initial preparation requires
recreating the processor; after successful prewarming, reset failure can recover.
The existing 48 kHz error fallback preserves input, while the research 16 kHz
path silences writable samples. Realtime/device testing, model rights and
complete acceptance remain open.
