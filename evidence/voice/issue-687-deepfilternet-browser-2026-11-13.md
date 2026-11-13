# Issue 687: experimental DeepFilterNet browser results

An isolated experimental AudioWorklet was exercised in Windows Chromium and
Firefox using the local WASM and model identified in
`issue-687-deepfilternet-research-2026-11-13.md`, without adding those assets
to the release build. Both browsers passed synthetic tone processing, mute,
reset/unmute and destruction, and rejected a corrupt model without raw audio
passthrough (two browser tests each). The meter test waits for pre-reset
messages to drain; it does not measure the immediate acoustic transition.

Unit tests additionally cover bounded frame buffering, nonfinite samples,
overload, engine errors and per-instance entropy isolation/zeroization. A
separate synthetic two-node test in both browsers verified that destroying one
node does not stop the other from processing.

The research-only same-origin loader verified the actual local WASM and model
hashes and compiled the WASM in Chromium and Firefox. Unit tests check bad
hashes, invalid content type, oversized streaming responses and timeouts;
these checks do not establish release asset provenance or delivery.

An experimental TrackProcessor loaded the same assets and processed a
synthetic MediaStream track in Chromium and Firefox; its derived track was
disabled after mute. Firefox stopped delivering frames in that state, while
the separate direct-worklet test showed zero output. Unit tests cover stale
preparation cancellation, unsupported sample rate and unmute/error races.
These runs did not publish to LiveKit or use a physical microphone.
The processor now waits for a disposal acknowledgement before closing its
port; unit tests exercise that acknowledgement, timeout and cancellation while
disposal is pending. Browser track and direct-peer checks passed again after
this change. This is not a long-running memory-leak measurement.

Another test connected two peer connections in one browser process without an
SFU. In both Windows Chromium and Firefox, the receiver measured a processed
synthetic tone, followed by silence after mute. This is a loopback WebRTC
check, not a two-client LiveKit or acoustic acceptance test.

The separate two-browser LiveKit experiment on Windows used the official
v1.13.7 binary (archive SHA-256
`e539e7d2f75807b9c9202cd2a0bf2cb3d52fc4c52978a6953e0f47bc339fe77f`)
on loopback only. Both the new research test and the existing RNNoise test
failed to establish the receiver peer connection before model initialization.
Enabling the server's loopback candidate did not resolve it. The cause is
unknown; this is not evidence that DeepFilterNet media works through LiveKit.
The test server was stopped and experimental assets removed from public paths.

The experimental processor is now wired to the Web microphone adapter behind
`VITE_DEEPFILTER_ENABLED=true`, with the flag disabled by default. In Windows
Chromium and Firefox, an explicitly enabled synthetic LiveKit LocalAudioTrack
passed through that adapter to a mock publisher, and mute silenced its output.
When the WASM request was forced to fail, both browsers restored a simulated
browser suppression setting and reported `asset-load` before mock publication.
These tests override capture settings and do not connect to a LiveKit server.
The selection UI is available only when explicitly enabled; release assets are
absent and no default user receives this engine. Real fallback, physical microphone, runtime cost, sustained operation,
voice quality, delivery and platform acceptance remain unestablished.

The adapter now requires an explicit browser report that built-in noise
suppression is off before enabling DeepFilter. Disabled builds, ignored or
unreported capture settings fall back without attaching the model. Unit tests
also cover an unavailable model, a failed fallback, a timed-out unmute and
reported failure reasons. These tests do not replace real-device verification.
The local real-stack gate remains BLOCKED: Ubuntu WSL and Docker did not
respond during this iteration; no unrelated services were restarted.
