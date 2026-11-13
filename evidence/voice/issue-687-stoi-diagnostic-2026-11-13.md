# Issue 687: exploratory STOI and ESTOI diagnostics

The eight CC0 Common Voice inputs and corresponding offline engine outputs
from `issue-687-speech-inputs-2026-11-13.md` and
`issue-687-deepfilter-speech-2026-11-13.md` were compared at 48 kHz using
[pystoi 0.4.1](https://github.com/mpariente/pystoi). The original recordings
were used as the reference, but their cleanliness is **unknown**, so the
prerequisite of a clean reference is not established. These numbers are
diagnostic only and are not valid speech-intelligibility acceptance scores.

| Offline engine | Alignment | STOI min / median / max | ESTOI min / median / max |
| --- | ---: | --- | --- |
| RNNoise v0.1 | 480 samples | 0.9589 / 0.9915 / 0.9998 | 0.9202 / 0.9861 / 0.9996 |
| RNNoise v0.2 research | 960 samples | 0.9303 / 0.9984 / 0.9998 | 0.8686 / 0.9970 / 0.9995 |
| DeepFilterNet3 research | 1440 samples | 0.9691 / 0.9892 / 0.9993 | 0.9484 / 0.9849 / 0.9984 |

Alignments use synthetic correlation lags, not speech-specific timestamps.
Input/output hashes, exact dependency versions and unrounded aggregate values
are recorded in `issue-687-stoi-fixture-results-2026-11-13.json`. The small,
unbalanced corpus lacks controlled paired noise conditions. These values do not
establish a winner, word preservation, user preference, realtime performance,
or a GO decision; blind listening and physical-client acceptance remain NOT_RUN.
