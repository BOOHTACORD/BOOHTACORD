# DeepFilterNet WASM ownership experiment

`wasm.rs` is a local replacement for the WASM interface in DeepFilterNet at
commit `d375b2d8309e0935d165700c91da9de862a99c31`. It exposes a wasm-bindgen
object with an explicit `free()` instead of leaking the upstream raw pointer.
It validates frame length and nonfinite input/output and returns sanitized
errors. Its experimental `reset()` clones the pristine initialized state;
its cost and memory use must be measured in a real AudioWorklet. An isolated
experimental AudioWorklet now exercises the model. A research-only loader pins
the experimental asset hashes and bounds fetch size and time; it is not wired
to a reproducible release. An experimental TrackProcessor is wired to the Web
microphone adapter and settings behind an off-by-default flag, with tested mock
publication and asset-failure fallback. Synthetic local SFU checks now pass;
full media acceptance, confirmed overload recovery and release delivery remain open.

The preliminary build applied WorkAdventure/noise-suppression commit
`7e00a1b7522f044a31776fddc249a97a98de94ed`'s tract 0.23 patch. Its
canonical Git blob SHA-256 is `88c73ae73ac1aaa99a72e8795e7fd41a67f4cd0f7cb49c1f69aeb70fe8c4abc9`;
the CRLF checkout used for the experiment hashes to
`495df6892ac879c0db80ccdb2aecbe939e4efc555d6c4fc8af2fab573d214d16`. The build
excluded unused dataset/HDF5 workspace dependencies, and pinned tract 0.23.8,
wasm-bindgen 0.2.118 and js-sys 0.3.95. The resulting experimental Cargo.lock
SHA-256 is `83b27804cbfbe8167d62b2f839bf4d3bbd4adb1ea1deecc9b35c97ee6e98aa0b`;
a pinned lock and research builder are now supplied; release provenance and
independent-machine reproducibility remain unverified.
The official model SHA-256 is
`c94d91f70911001c946e0fabb4aa9adc37045f45a03b56008cb0c8244cb63616`.

`node tools/audio/research_dfn_web/probe.mjs <generated-js> <wasm> <model>`
exercises five initialization, invalid-frame, processing and free cycles, then
compares output after reset to a fresh state on synthetic frames. It
prints only aggregate WASM memory sizes, not audio. The probe does not prove
browser cleanup, absence of leaks, timing, model licensing, acoustic quality or
release readiness. See `evidence/voice/issue-687-deepfilternet-research-2026-11-13.md`.

For licensed offline 48 kHz mono float32le fixtures, `speech.mjs` accepts
`--input <file> --sha256 <hash> --output <new-file> --glue <js> --wasm <wasm>
--model <tar.gz>`. It verifies the input and pinned research assets, pads frames
and appends the same 120 ms tail as the RNNoise fixture. It will not overwrite
the destination. Do not use private calls or record microphone audio with it.

## Rebuilding the research bundle

Given local Git repositories containing the pinned upstream and WorkAdventure
commits, Rust/Cargo 1.97.1 with the wasm32 target and wasm-bindgen 0.2.118:

```
python -m tools.audio.research_dfn_web.build --source <upstream-repo> --patch-source <workadventure-repo> --work <new-directory> --bindgen <wasm-bindgen> --offline
node tools/audio/research_dfn_web/stage.mjs <new-directory>/bundle <new-stage-directory>
```

The builder validates the upstream model, patch, Cargo lock, generated WASM
and generated JavaScript hashes; it does not overwrite an existing directory.
It remaps Cargo and source paths before compilation so local directory names do
not leak into the WASM or change its identity.
The stage command creates the worklet and model file layout without writing to
`clients/web/public`. An opt-in Web build may consume the bundle with
`VITE_DEEPFILTER_ENABLED=true` and `BOOHTA_DEEPFILTER_RESEARCH_BUNDLE` pointing
to that validated bundle. The default build omits these experimental assets;
missing or modified opt-in assets make the build fail. No research bundle is
published by these commands.

For local browser tests, set `BOOHTA_RESEARCH_ASSET_DIR` to the staged directory.
`python -m tools.audio.research_dfn_web.livekit_windows --binary <trusted-server>
--web clients/web` creates a short-lived local server with random test keys and
restricted candidate interfaces. It stops on a wildcard listener and removes
its temporary configuration. No tokens or audio are intentionally logged.
The workflow `audio-web-research.yaml` is configured to exercise this chain;
its hosted result and release acceptance must be verified separately.
