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
```

The output directory must not exist and must be under `.out/audio-research`.
This scalar probe has no SIMD, runtime dispatch, production integration, release
license clearance, or proof of real-time behavior. SHA matching alone does not
establish perceived quality or source authenticity.
