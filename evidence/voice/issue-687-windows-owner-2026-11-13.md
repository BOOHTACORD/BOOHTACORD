# Issue 687: experimental Windows owner integration

At parent source `72f2711c4` with the changes in this packet, a Windows MSVC
Release build of `flutter_webrtc_plugin` passed both with the experimental
native loader explicitly enabled and with its default OFF. The enabled build
used dummy SHA-256 values and included no actual model; configuration with an
invalid hash failed as intended. The build cache was returned to OFF.

The optional owner holds the verified engine, worker and capture hook until
the WebRTC factory has stopped; an unavailable or mismatched artifact leaves
the existing capture adapter without this hook. The separate Flutter UI flag
also remains OFF by default. The optional build expects pinned hashes at build
time and files beside the executable, but release packaging, signing, safe
updater delivery and complete path trust are not implemented.

All 19 native MSVC CTests passed. The new owner test used a test DLL and stub
WebRTC API, checked failure/retry, preparation, synthetic processed frames,
mode change and destruction. A separate synthetic owner/adapter probe loaded the locally built research
DLL (`a7d07b7b2231b5ed4afa5b3a2a1a812054cea5a25e007b27b5a309cf2a421f48`)
and model (`c94d91f70911001c946e0fabb4aa9adc37045f45a03b56008cb0c8244cb63616`).
One run prepared in 307 ms, submitted 300 frames, processed 296 and observed
zero fallback frames. It used a stub WebRTC interface, not the compiled plugin.
No microphone, network call, installed client, GUI or release artifact was run. Those acceptance gates remain NOT_RUN, as do the full requirements of
issue 687. No server deployment was performed.
