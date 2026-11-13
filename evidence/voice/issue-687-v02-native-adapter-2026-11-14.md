# Issue 687: native RNNoise v0.2 capture processor research

On Windows x64 with MSVC 19.44, an isolated research build linked the existing
`RnnoiseCaptureProcessor` to the verified upstream v0.2 core and local weights
via a small bridge for the changed initialization signature. The upstream
source commit and generated model/header hashes were checked before building;
the generated binaries remain in ignored local output and are not published.

Three CTests passed: the existing processor lifecycle/format test, a new
100-frame synthetic comparison between the capture processor and direct v0.2
calls at 48 kHz, and a separate opt-in research path for 16 kHz input. The
research path uses the existing fixed-buffer 16 -> 48 -> 16 kHz resampler;
100 output frames matched a direct v0.2 plus resampler reference within 0.001
on S16-scale samples. Tests also checked invalid PCM, short capacity and a
deterministically induced mid-frame engine change, with silence where writable.
The ordinary nonexperimental path still rejects 16 kHz input.
The separate native suite, built without the research flag, passed 21/21 tests.

The initial three-test executables' SHA-256 values were:

- `native_v02_adapter_test.exe`: `a8daf95cadecc3af5e0b14e9586c04ece3824affcb2ce221cb1f98a0ba31f851`
- `native_v02_parity_test.exe`: `ad95a4d2663e9efcf6ca7709fb5fc6876d34fc771d0f56e9e0847110363b4dd0`
- `native_v02_16k_test.exe`: `7848585ab53b47d96ac3638f5795500c8d5d9a4cc11f743edc58478168d79a5d`

This is a local component experiment, not a Windows client or LiveKit test.
The experimental 16 kHz path is not wired into Flutter. The deterministic mid-frame test does not prove
race-free switching: the engine can change after the final generation check.
Realtime safety, real devices, quality, signed delivery and model distribution
rights remain unverified. No release or server deployment was performed.

Follow-up: the existing processor ignored the initialization return code. A
research bridge injected failures at construction and reset; the new test first
failed because the processor reported availability. The processor now tracks
initialization success and skips inference on failure, recovering after a
successful reset. At 16 kHz the research path silenced writable samples; the
ordinary 48 kHz fallback preserved its existing unchanged-input behavior. The
four research tests and the 21-test standard native suite passed on Windows.
The final `native_v02_init_test.exe` SHA-256 was
`f360447b9baab5948b43e0ce89d84bd1856a3670d6a1886fecdb75c40383ff7b`.
These injected failures do not prove production recovery or real-time safety.
