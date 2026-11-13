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
This scalar probe has no SIMD, runtime dispatch, production integration, release
license clearance, or proof of real-time behavior. SHA matching alone does not
establish perceived quality or source authenticity.
The native `rnnoise_v02_pcm` executable takes an existing mono 48 kHz float32le
input and a new output filename. It pads partial frames and appends 120 ms of
silence, like `tools/audio/speech_fixture/run.mjs`; an existing output is never
overwritten. It is for offline comparisons only, not microphone capture.
