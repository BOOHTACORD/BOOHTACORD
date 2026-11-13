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

This research processor is not connected to LiveKit or an application setting.
Its runtime cost, sustained operation, real microphone, voice quality,
delivery, safe fallback and platform acceptance are not established.
