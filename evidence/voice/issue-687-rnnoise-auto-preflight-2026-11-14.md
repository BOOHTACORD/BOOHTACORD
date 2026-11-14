# Issue 687: asynchronous RNNoise Auto preflight

Status: PARTIAL. A capability request starts a single worker with independent
RNNoise state and synthetic PCM. It reports idle/running/passed/failed plus
p95/max inference durations. Capture receives no extra allocation, lock, timer
or join. The worker owns its state until completion; destruction joins it on
the control thread. Global FFT warmup now shares one once flag between control
initialization and worker setup. A hung native call is not interruptible.

Windows Auto can select RNNoise without the debug override only for a
confirmed `rnnoise-stock-v0.2` and completed preflight with finite integral
timings, p95 <=3ms and max <=8ms. Unknown/old models, failed or malformed
measurements fall back to browser suppression. Polling is bounded and a
cancelled generation does not configure a stale engine. Debug research overrides
remain explicit and separate. This does not make the default v0.1 build v0.2.

Observed local probes: v0.1 p95 107us / max 132us; source-verified scalar v0.2
p95 182us / max 217us, both passed eligibility on this Windows host. These are
40 synthetic frames per model, not physical speech or sustained CPU evidence.
The full default native suite passed 25/25. Fourteen focused Flutter Auto,
initial-capture, cancellation and settings tests passed with fake method calls;
targeted Dart analysis passed. Actual capability/Auto execution through the
running Flutter plugin and production release acceptance remain unverified.
DeepFilter Auto selection, dynamic adaptation, physical speech, rights, signed
delivery and release gates remain open. No model publication or server deploy.
