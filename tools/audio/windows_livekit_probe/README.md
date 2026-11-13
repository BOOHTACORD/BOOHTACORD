# Local Windows LiveKit voice probe

This research-only Flutter entrypoint requires an isolated LiveKit instance,
short-lived room tokens for two test participants, an explicitly enabled native
DeepFilter build and the matching research artifacts beside the executable. It
uses the local microphone with the owner's consent; select an appropriate quiet
space. It does not record PCM, SDP, access tokens, track IDs or usernames.

From `clients/flutter`, configure the experimental Windows CMake flag and pinned
hashes as described in `../windows_client_probe/README.md`, then build with
`flutter build windows --release --no-pub --target
../../tools/audio/windows_livekit_probe/main.dart`. Copy the build into a fresh
isolated directory with the matching research DLL and model. The probe connects
to `ws://127.0.0.1:17880`. Set `BOOHTA_PROBE_SENDER_TOKEN` and
`BOOHTA_PROBE_RECEIVER_TOKEN` in the process environment to distinct,
short-lived tokens scoped to the same test room; never print or persist them.
Set `BOOHTA_AUDIO_PROBE_RESULT` to a new output path. It records only aggregate
processor state, subscription and RTP counts, and returns nonzero on failure.

Restrict signaling to loopback and RTC candidates to the private local interface;
use random temporary server credentials and stop the test server afterwards.
Never use production credentials, a production server or the installed client.
This short probe does not establish listening quality, 30-minute stability,
other devices, release safety or signed-install behavior.
