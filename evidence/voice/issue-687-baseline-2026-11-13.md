# Issue 687: baseline and acceptance status

Source: `02dd970d62ca1a349b50cb9a3df363cbc181a3a9` (master).
The application DSP was not modified for the baseline checks below.

| Check | Result | Scope |
| --- | --- | --- |
| Existing native DSP tests | PASS | 3/3 in Ubuntu WSL, GNU toolchain; not a Windows build or call |
| Native DSP sanitizers | PASS | Ubuntu WSL Debug, ASan/UBSan; CTest 3/3. The downstream include check builds a separate configuration |
| Native Windows DSP tests | PASS | MSVC 19.44, Windows SDK 10.0.26100, Release, CTest 3/3; standalone DSP, not the installed client or a call |
| Existing native fixture cross-compiler comparison | DIAGNOSTIC | 48,000 output samples: Windows MSVC vs WSL GCC max absolute difference 8.44812 and RMS 1.53560, on the float S16 scale. Inputs are generated independently by each executable; no tolerance or identical PCM input was established, so this is not a parity PASS |
| Synthetic corpus identity | PASS | Windows Node 24.18.0 and WSL Node 24.19.0; exact float32le SHA-256 in `tools/audio/corpus/synthetic-v1.json` |
| RNNoise v0.1 WASM synthetic baseline | PASS | Emscripten 4.0.20, scalar, Node 24.18.0 on Windows; fixture noise RMS change -6.517 dB, correlation lag 479 samples, core frame CPU p99 0.197 ms. WASM SHA-256 `c9e99c9a9b04c8a9f048f3961f95657c3d0b21cf6280d1d518dbf63aeedd1604` |
| Web unit and Chromium synthetic graph | PASS | 51 unit tests and 4 Chromium 153.0.8010.12 tests, including direct WebRTC peer; LiveKit, real microphone and other browsers NOT_RUN |
| Speech quality, hearing and real-device delay | NOT_RUN | An incomplete public corpus subset is prepared; no blind panel or loopback result |
| Native Windows microphone and browser real audio | NOT_RUN | No physical microphone or end-to-end call tested |
| RNNoise v0.2 and DeepFilterNet3 acceptance | NOT_RUN | New engines are not implemented |

The synthetic chirp is not speech. These checks do not establish speech
preservation, perceived quality, processing latency, or a user incident cause.
The measured correlation lag and Node frame CPU are not end-to-end latency or
AudioWorklet callback timing.
Do not close issue 687 or change the default based on these results.

Upstream reconnaissance: Xiph's annotated `v0.2` tag resolves to commit
`904a876dce1f9ab8860c0a5000ed151f9f6eef58`; its `model_version` is
`0b50c45`. The upstream model download has SHA-256
`4ac81c5c0884ec4bd5907026aaae16209b7b76cd9d7f71af582094a2f98f4b43`.
The model archive contains no separate license file; its redistribution
terms still need verification independently of the source-code license.
This download is research material, not a shipped or verified release asset.
The upstream [license question](https://github.com/xiph/rnnoise/issues/284)
explicitly asks about this archive and remains open; it is not a license grant.
DeepFilterNet's [license clarification](https://github.com/Rikorose/DeepFilterNet/commit/7b14b895fe7fc42cab72b4a4c1e49c982bd6404b)
states that repository model weights are dual-licensed MIT/Apache-2.0. The exact
files selected for a release and their hashes still need individual verification.
Browser-adapter investigation at WorkAdventure commit
`7e00a1b7522f044a31776fddc249a97a98de94ed`: its DeepFilterNet worklet
defaults to bypassing audio while loading or after a failure. That default
must not be adopted without reconciling it with BOOHTACORD's mute, fallback,
asset integrity, and generation guarantees. No adapter was integrated.
An isolated Ubuntu/GCC build of those upstream sources initialized the default
model and returned finite near-zero output for 100 silent frames; frame size
was 480 and state size 32688 bytes on that build. This is a feasibility smoke
test, not an application integration, numerical parity, or Windows result.

An isolated scalar v0.2 WASM probe, using the same synthetic corpus, returned
noise RMS change -76.441 dB, correlation lag 959 samples and Node frame CPU
p99 0.426 ms. Its WASM SHA-256 was
`f121a4c5f398e565058cdeb1301c7441c50cbed857e5898cfd39a0feaae43859`.
The v0.2 source refers to an absent `os_support.h` on the scalar path; the
probe used a local one-line `OPUS_CLEAR` shim. It was built outside the release
tree and is not a supported or distributable artifact. This does not prove
speech quality, platform compatibility, release eligibility, or end-to-end
latency. The greater synthetic correlation lag warrants physical measurement.
