# Issue 687: native Auto candidate preparation

Status: PARTIAL. A loaded experimental DeepFilter owner reports its model ID
only when the verified weights match the pinned c94d91f7 SHA-256. Fixture and
unknown models do not acquire that identity. With the existing explicit
DeepFilter enable flag, Auto attempts this candidate, waits for native worker
preflight readiness, and on failure tries measured RNNoise v0.2, then WebRTC.
Selected preparation stays separate from requested Auto and active processing.
Default preferences and explicit OFF are unchanged. No new mode is exposed in UI.

Tests reproduced the missing DeepFilter selection/failover before the change.
Flutter fake-channel tests pass for DeepFilter success, fallback to measured
RNNoise, unknown-model rejection, waiting, cancellation and settings capture.
The full default native suite passed 25/25 and targeted Dart analysis passed.
A real checksum-verified native owner probe verified the model identity and
processed 296 of 300 submitted synthetic frames with zero fallback, after
709ms preparation. This is the native owner/adapter path, not Dart Auto through
a real channel, a physical microphone, or a LiveKit call.

Actual client acceptance, device/reconnect/mute and sustained real-speech
testing, dynamic adaptation, model distribution rights, signing and releases
remain open. No release or server deployment.
