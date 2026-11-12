# Issue 687: soft VAD transitions

Web and Windows now ramp VAD opening over 5 ms and closing over 50 ms. The
existing 20 ms delay, threshold/hysteresis, hold, gain and non-VAD path remain.
The native change is guarded by `_WIN32`; a Linux native test exercised the
unchanged branch. Android and iOS device regression remains NOT_RUN.

The Web DSP baseline is Git blob `28d6a1cd51506f3ce99b61d6d439bb74eac5a53e`
at commit `42be2bbab80c27cceaae1d00d54b884107a9c715`; the new DSP blob is
`defe5ff512c7f4458c42dbe3dfc9638881884050`. The Windows native implementation
blob is `dbe669704a15e01af7c3ae737164fcc3466bcb0b`. Focused tests exercise
attack, release, a synthetic quiet 10 ms onset inside the existing pre-roll,
non-VAD bypass and reset; Windows MSVC CTest 5/5 and Web unit tests passed.

For an exploratory comparison, eight locally held CC0 Russian Common Voice
clips listed in `issue-687-speech-inputs-2026-11-13.md` were each scaled to
whole-clip RMS -45 dBFS, with threshold -50 dBFS and identical input bytes.
`node --experimental-transform-types tools/audio/gate_compare/run.mjs
<baseline.mts> <input-directory>` compares a baseline DSP exported from the
commit above with the current source. At 48 kHz across 2,325,888 samples and
15 gate-closing transitions, the mean sample jump at the exact closing boundary
was 0.00018462 baseline and 0.00005811 current; maximum was 0.00053104 and
0.00026309. Whole-output RMS was 0.00562228 and 0.00562214 respectively.
Gate decisions were identical. These metrics do not establish audible quality,
quiet-word preservation or leakage in the 50 ms release interval. No listeners,
physical microphone, AEC/AGC, CPU benchmark or 30-minute native run was used;
speech quality and release decisions remain NOT_ASSESSED.
