# Local Windows RNNoise v0.2 diagnostics

These probes require microphone-owner consent. They capture a physical
microphone but do not save PCM, SDP, participant IDs or tokens. `main.dart`
uses two local WebRTC peers; `livekit.dart` tests a full reconnect through a
local SFU; `switch.dart` tests RNNoise → DeepFilterNet3 → RNNoise in one call.
The receiving audio track is muted in the LiveKit probes.

Use a dedicated worktree and local Windows build directory. Set
`BOOHTA_RNNOISE_V02_SOURCE` to the verified upstream checkout, set
`BOOHTA_RNNOISE_LOCAL_ONLY=1`, and build one entrypoint with Flutter's
`--target` option. CMake verifies the pinned source, weights and header before
building; the build is rejected in CI. The installed research marker prevents
the project installer and native release validator from accepting the result.
This accidental-release guard is not a signature or an authorization to
distribute the weights.

The `switch.dart` entrypoint also requires the existing experimental DeepFilter
native flag, pinned DLL/model hashes and their matching research files beside
the executable. `python -m tools.audio.windows_v02_probe.livekit --help`
describes the local SFU runner. Supply a trusted server binary with its SHA-256,
a Web package directory containing the pinned `livekit-server-sdk`, and a new
result path below `.out/audio-research`. The runner binds signaling to loopback,
restricts candidates to the selected private interface, uses short-lived
credentials and stops the owned server afterward.

These probes do not establish speech quality, end-to-end latency, live user
calls, long-duration stability, signed delivery or release readiness. Do not
copy the research build or model files into a distribution.
