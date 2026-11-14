# Local native Auto diagnostic

Build a separate marked Windows research client with verified RNNoise
v0.2 and the existing experimental native DeepFilter flag/DLL/model hashes.
Target this directory's `main.dart`, set `BOOHTA_AUTO_PROBE=true`, and leave
`BOOHTA_RESEARCH_AUTO_ENGINE` empty. Missing research markers are rejected.
Debug tests both candidates using the existing debug-only injection of backend
availability. Optimized builds test one candidate per build: choose it with
`BOOHTA_EXPERIMENTAL_DEEPFILTER=false` or `true`, without an engine override.
An optimized research build is not an authorized release artifact.

With microphone-owner consent in a suitable environment, run only from a fresh
isolated directory, with the verified research DLL/model beside the executable.
Set `BOOHTA_AUDIO_PROBE_RESULT` to a new file below `.out/audio-research`; use a
supervisor with a bounded deadline. Do not replace the installed client.

The probe calls the actual shared NativeNoiseSuppression Auto service without
research engine overrides: first RNNoise eligibility, then enabled DeepFilter.
Each phase captures six seconds of microphone input. By default it uses two
local WebRTC peers with no ICE servers. The existing isolated local LiveKit
runner selects the SFU variant by supplying its ephemeral sender/receiver tokens
through the environment. Receiver playback is muted. Only
bounded engine states and packet/byte/frame counters are saved. No PCM, SDP,
device or participant identifiers, or credentials are saved.

For optimized local SFU endurance, set BOOHTA_AUTO_PROBE_SECONDS=1800 and
the supervisor --timeout to 1900. Duration accepts only 6..1800 ASCII seconds;
longer debug or direct-peer runs are rejected. Every interval (at most five
seconds) must advance both processing and received packets with no fallback
and the expected active engine; a successful first interval cannot hide a stall.
This continuous physical-capture check does not imply speech was present.

This is method-channel and local media evidence. It does not prove listening
quality, production calls, AEC/AGC effectiveness, reconnection, hotplug,
long-duration stability, model rights or signed release acceptance.
