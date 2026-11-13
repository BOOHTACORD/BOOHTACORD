# Issue 687: synthetic model comparison

On Windows with Node 24.18.0, the frozen CC0 synthetic corpus
`tools/audio/corpus/synthetic-v1.json` was run with equal input levels and no
normalization through the checked-in RNNoise v0.1 WASM and pinned local
RNNoise v0.2 and DeepFilterNet3 research WASM/models. Each signal was
processed from reset.

| Diagnostic | RNNoise v0.1 | RNNoise v0.2 research | DeepFilterNet3 research |
| --- | ---: | ---: | ---: |
| Noise RMS change | -6.52 dB | -76.44 dB | -24.86 dB |
| Synthetic signal correlation lag | 479 samples | 959 samples | 1440 samples |
| Node per-frame CPU p99 | 0.192 ms | 0.438 ms | 1.082 ms |

The measured WASM and model hashes are emitted by the harness. These are
different research implementations, not matched production releases. This
short synthetic stationary-noise/chirp comparison does not establish speech
intelligibility, acoustic preference, callback budget, device load, or
end-to-end delay. The observed model lag excludes the native queue delay;
the two measurements must not be added as a real-call latency measurement.
A later DeepFilterNet diagnostic run reported no samples above unit amplitude
and a peak of approximately 0.059 on these three low-amplitude inputs; this
does not rule out clipping on other inputs or in the rest of the audio chain.
