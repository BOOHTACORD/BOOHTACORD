# Issue 687: first real Windows Auto loopback attempt

Status: FAIL. A separate marked debug diagnostic called the actual shared
Auto service through the real plugin, with verified RNNoise v0.2 and pinned
DeepFilter DLL/model. Without engine overrides, phase 1 selected RNNoise and
phase 2 selected DeepFilter; both preserved requested Auto. Microphone format
reported mono 16kHz, but neither phase processed frames or received RTP packets.
Remote track events alone did not prove a connected media path.

The probe muted receiver playback and retained no audio. It exited 1 and was
not installed. The cause of zero media is undetermined; connection and capture
state diagnostics, plus a local LiveKit path matching the app, are next.
This does not establish physical Auto acceptance or an acoustic regression.

Executable SHA-256:
`9427cce271c0163716f46fb3de3ceca0fd049fea7bda6198e43d8afb81e74559`.
DLL: `a7d07b7b2231b5ed4afa5b3a2a1a812054cea5a25e007b27b5a309cf2a421f48`.
Model: `c94d91f70911001c946e0fabb4aa9adc37045f45a03b56008cb0c8244cb63616`.
Aggregate result is local `.out/audio-research/auto-physical-1114-v1.json` in
the integration checkout. No server deployment or model publication.
