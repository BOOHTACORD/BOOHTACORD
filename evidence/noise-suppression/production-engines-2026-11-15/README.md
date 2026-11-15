# Ordinary Web and Windows noise engines

Source base: `6f3f536d33205d6a5e2a39829924137af4e6e65b`.
Candidate: Windows 1.0.56+92/r71; Web 1.0.56/r64.

## Delivery and identity

- Windows CMake defaults to the complete official RNNoise 0.2 distribution.
  Archive, model C and COPYING hashes are checked before compilation.
  `rnnoise-engine.json`, BSD notice and the matching SBOM travel with the app.
- Windows also compiles pinned DeepFilterNet3/libDF 0.5.7-pre from source, with
  Rust 1.97.1, the locked graph, static CRT and panic containment. The allocation
  counter is omitted. CMake binds the delivered DLL/model hashes into the hook.
- DeepFilterNet README at `7b14b895fe7fc42cab72b4a4c1e49c982bd6404b`
  explicitly covers code and model weights under MIT/Apache-2.0. Original model,
  upstream, 161 Cargo package and Rust standard-library notices are delivered.
- Web vendors qualified distributable WASM/models and notices. Ordinary
  `npm run build` emits both without research flags or a local Rust/Emsdk SDK.
  The Vite plugin checks every byte against the committed delivery identity.
  Node/Alpine Docker builds copy the same authenticated assets.
- The Web DeepFilter bytes match producer run `43618192571`, artifact
  `14123930408`, source `9a44c83602fa44981aeeaa65e8321c1f714783d4`.
  That producer archive was independently downloaded and SHA256 checked.
  New CI rebuilds both engines and compares the shipped bytes before browser QA.
- Public settings show RNNoise 0.2, DeepFilterNet3 and Auto. Runtime details
  retain actual model IDs. Explicit legacy/disabled selections remain rollback
  controls; no research RNNoise weights enter the production distribution.
- Android/macOS engine selection remains unchanged. This delivery is Web and
  Windows only. Existing unsigned Windows publication policy remains explicit.

## Local verification

| Check | Result |
|---|---|
| Official source extraction/cache tamper, notices, compiler/signing ordering | PASS, 12 tests |
| Native artifact provenance and public asset contracts | PASS, 12 tests |
| Native DSP/capture/mute/16 kHz/model tests | PASS, 27 tests |
| Full Web unit suite | PASS, 581 files / 1998 tests |
| Focused Flutter settings/cold startup/Auto/fallback | PASS, 35 tests |
| Ordinary optimized Windows build, no engine flags | PASS |
| Windows local microphone and two independent RTC peers | PASS, both engines |
| Ordinary browser RNNoise graph, resets, 100 transitions, RTP/mute | PASS |
| Ordinary browser DeepFilter track, mute and worker preflight | PASS |
| Browser runtime total | PASS, 7 tests |
| Ordinary Web production build | PASS |
| Browser versioned selection desktop/mobile | PASS, 3 tests |

`windows-runtime.json` contains only aggregate states and counters. Both paths
processed real capture frames with zero fallback frames and received 300 RTP
packets. Receiver playback was muted; no PCM, credentials, SDP or device IDs
were saved. RNNoise was selected manually; the ordinary Auto policy selected
DeepFilter. The earlier probe's RNNoise expectation was corrected to distinguish
manual selection from Auto's legitimate DeepFilter preference.

Two independent RNNoise Web builds matched SHA256
`6e45ec094afad2bcd816ff0f1a55e6d34ffa0935f8aa85cf70ff741834904e41`.
Synthetic Node quality harness passed; this is not speech-quality evidence.

Visual observations and source-resolution screenshot digests are in
`visual-review.json`. Desktop/mobile settings have no clipping or overlap.
Native widget/version assertions and real native media are separate proofs;
the complete installed workspace UI is not claimed.

The broad local feature runner is tracked separately. Docker Desktop's Linux
daemon was unavailable at preflight. A failure/blocked stage cannot be counted
as passing; applicable hosted CI and release delivery still must complete.
Full original #687 blind listening, long-duration acoustic/AEC/AGC and complete
workspace/device acceptance are not established by these bounded checks.

## Release gate

At authoring: PR/master CI, immutable Windows publication, catalog promotion and
live Web rollout are PENDING. Refresh this section with their actual executions.
