# DeepFilterNet WASM ownership experiment

`wasm.rs` is a local replacement for the WASM interface in DeepFilterNet at
commit `d375b2d8309e0935d165700c91da9de862a99c31`. It exposes a wasm-bindgen
object with an explicit `free()` instead of leaking the upstream raw pointer.
It validates frame length and nonfinite input/output and returns sanitized
errors. Its experimental `reset()` clones the pristine initialized state;
its cost and memory use must be measured in a real AudioWorklet. An isolated
experimental AudioWorklet now exercises the model. A research-only loader pins
the experimental asset hashes and bounds fetch size and time; it is not wired
to the client or a reproducible release. An experimental TrackProcessor
creates and mutes a derived browser track and cancels stale preparation; it is
not connected to LiveKit. Adapter integration, overload fallback and release
delivery do not exist yet.

The preliminary build applied WorkAdventure/noise-suppression commit
`7e00a1b7522f044a31776fddc249a97a98de94ed`'s tract 0.23 patch. Its
canonical Git blob SHA-256 is `88c73ae73ac1aaa99a72e8795e7fd41a67f4cd0f7cb49c1f69aeb70fe8c4abc9`;
the CRLF checkout used for the experiment hashes to
`495df6892ac879c0db80ccdb2aecbe939e4efc555d6c4fc8af2fab573d214d16`. The build
excluded unused dataset/HDF5 workspace dependencies, and pinned tract 0.23.8,
wasm-bindgen 0.2.118 and js-sys 0.3.95. The resulting experimental Cargo.lock
SHA-256 is `83b27804cbfbe8167d62b2f839bf4d3bbd4adb1ea1deecc9b35c97ee6e98aa0b`;
the full lock and reproducible production builder are not yet supplied.
The official model SHA-256 is
`c94d91f70911001c946e0fabb4aa9adc37045f45a03b56008cb0c8244cb63616`.

`node tools/audio/research_dfn_web/probe.mjs <generated-js> <wasm> <model>`
exercises five initialization, invalid-frame, processing and free cycles, then
compares output after reset to a fresh state on synthetic frames. It
prints only aggregate WASM memory sizes, not audio. The probe does not prove
browser cleanup, absence of leaks, timing, model licensing, acoustic quality or
release readiness. See `evidence/voice/issue-687-deepfilternet-research-2026-11-13.md`.
