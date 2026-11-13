# Local Windows voice probe

This opt-in diagnostic builds a separate Flutter entrypoint and sends microphone
audio only between two WebRTC peers on the same machine, with no ICE servers.
It must be run with the microphone owner's consent in a suitable environment.
It does not save PCM, SDP, candidates, usernames or track identifiers. Only
aggregate processor states and inbound packet/byte counts go to the output file.

The test requires a research-only DeepFilter DLL and model whose SHA-256 values
are configured in the Windows CMake build with
`BOOHTA_DEEPFILTER_EXPERIMENTAL_NATIVE=ON`,
`BOOHTA_DEEPFILTER_DLL_SHA256` and `BOOHTA_DEEPFILTER_MODEL_SHA256`. Build this
entrypoint using `flutter build windows --release --no-pub --target
../../tools/audio/windows_client_probe/main.dart` from `clients/flutter`.
Copy the build to a fresh isolated directory and place the verified research
files beside the executable as `boohta_deepfilter.dll` and
`boohta_deepfilter_model.tar.gz`. Set `BOOHTA_AUDIO_PROBE_RESULT` to a new
output path before launching the isolated executable. The probe exits nonzero
if preparation, capture, RTP delivery or processing fails.

This is a short diagnostic, not signed release, server/LiveKit acceptance,
listening-quality assessment, device-switch testing or a 30-minute stability
test. Do not replace the installed client or include research assets in a
release on the basis of this probe.
