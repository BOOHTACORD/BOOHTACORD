# Offline research speech metrics

Install the pinned, hashed dependencies in an isolated Python 3.12 x64
environment with `pip install --require-hashes --only-binary=:all: -r
tools/audio/speech_metrics/requirements.txt`. The lock contains the Windows
and Linux x64 wheels used by the local experiment and CI.

Run one pair with `python -m tools.audio.speech_metrics.score --reference
<f32le> --reference-sha256 <sha256> --candidate <f32le> --candidate-sha256
<sha256> --lag-samples <n>`. Inputs must be authorized mono 48 kHz float32le;
the reference must actually be clean for STOI/ESTOI interpretation.

For multiple pairs, create a local JSON file with a `pairs` array; each object
contains `engine`, `reference`, `referenceSha256`, `candidate`,
`candidateSha256` and `lagSamples`. Then run `python -m
tools.audio.speech_metrics.batch --manifest <file>`. Output includes hashes,
versions and aggregate scores, but no local paths or audio. Do not use real
calls or private conversations. Warnings and nonfinite/short data fail closed.
Scores alone never constitute listening, device or release acceptance.
