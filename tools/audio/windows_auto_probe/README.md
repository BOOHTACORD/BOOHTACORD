# Local native Auto diagnostic

Build a separate marked Windows **debug** research client with verified RNNoise
v0.2 and the existing experimental native DeepFilter flag/DLL/model hashes.
Target this directory's `main.dart`; leave `BOOHTA_RESEARCH_AUTO_ENGINE` empty.
The probe deliberately rejects release builds and missing research markers.

With microphone-owner consent in a suitable environment, run only from a fresh
isolated directory, with the verified research DLL/model beside the executable.
Set `BOOHTA_AUDIO_PROBE_RESULT` to a new file below `.out/audio-research`; use a
supervisor with a bounded deadline. Do not replace the installed client.

The probe calls the actual shared NativeNoiseSuppression Auto service without
research engine overrides: first RNNoise eligibility, then enabled DeepFilter.
Each phase captures six seconds of microphone input and transmits only through
two local WebRTC peers with no ICE servers. Receiver playback is muted. Only
bounded engine states and packet/byte/frame counters are saved. No PCM, SDP,
device or participant identifiers, or credentials are saved.

This is method-channel and local media evidence. It does not prove listening
quality, LiveKit behavior, AEC/AGC effectiveness, reconnection, hotplug,
long-duration stability, model rights or signed release acceptance.
