# Issue 687: public speech input preparation

Eight clips were retrieved through the dataset viewer from the first eight rows
of the [Common Voice Russian v21 mirror](https://huggingface.co/datasets/Sh1man/common_voice_21_ru/tree/a4863eb7091db48fa824bfad6196f25bac4e3c38),
whose dataset card identifies CC0-1.0. Mozilla's [dataset catalog](https://commonvoice.mozilla.org/dav/datasets)
also lists Common Voice under CC0-1.0. Viewer audio is decoded 32 kHz mono PCM;
FFmpeg converted it to mono float32le at 48 kHz with no gain normalization.
Files stay in ignored local output. The recordings are not identified as quiet,
whispered, or balanced by speaker gender, and are insufficient for acceptance.
Prepared input SHA-256 in row order:

1. `be67b1318cba1d90dd7e79663eb3e5b578ac525748f373cf3ef481980e8d49fe`
2. `c07d6c2364a94304238dd3ee1e994e3b0d55bbb843866c78ba67d3e4dea8c0aa`
3. `bc691e5157dd6ad66ca733f20c358f406238e6cfd671bb35020cd46e67d03ab7`
4. `4d377f50270771b416b2219b00f67a317e94ad15cc25d6f850cfe30b6efca7d7`
5. `c01215e7399b43638640e5c97534cbb97cb541a2dd900356b2a0a5ace25d0e61`
6. `5efdd65a817e95f4921ee624ebcefc55a11d3d2d2ed71a820557e2baaca92b4e`
7. `3df7458576e7bfc04089e0939a493db1e2879f4f59a443e539e3de05ce5451fd`
8. `082c2451b4d77546bb2f69567d5a9d2e543e8e2a43072bcc63b31611b2022b46`

Both v0.1 and the isolated v0.2 WASM probe processed each of the eight inputs
offline (16 executions), with identical input bytes and no gain normalization.
Each output includes zero padding and 12 additional 480-sample tail frames.
No playback, intelligibility, speech-preservation or release decision follows
from successful execution. The v0.2 probe is not a release artifact.

For reproducibility, the first prepared input produced float32le output hashes
`277147a6daa7a879467be3de5b0181cdd8ffb3a420c773ef440d5e0845563bd6`
for v0.1 and `e4190c64a2c0535267f3347dbaedbbff63e8618af2d0b223d984dca99b1df951`
for v0.2. Playback and subjective ratings remain NOT_RUN.

As a diagnostic only, the output was aligned to the dry input using the
synthetic correlation lags rounded to 480 samples for v0.1 and 960 for v0.2.
Pearson correlations across the eight clips were min/median/max
0.8530/0.9857/0.9955 for v0.1 and 0.8485/0.9871/0.9952 for v0.2. These
recordings may already contain noise; there was no separate noise mix, AEC,
gate or real client. Correlation is not intelligibility or an assessment of
word loss and cannot establish that either model sounds better.

Separately, the existing Web `MicrophoneDsp` gate was run offline on those same
clips, each scaled to a chosen whole-clip RMS. At the default -50 dBFS gate
threshold, it reported closed on 910/4677 eligible 10 ms frames at -35 dBFS,
872/4427 at -45 dBFS, and 1682/4095 at -55 dBFS. Eligible means the frame
input was above the meter's -90 dBFS floor; it does not mean speech was present.
These are controlled level-scaling observations, not a measurement of words
lost or proof of the reported user incident. A listening/word-boundary test is
still necessary before changing the gate.
