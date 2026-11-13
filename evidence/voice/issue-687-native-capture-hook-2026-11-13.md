# Issue 687: Windows capture hook experiment

The production WebRTC capture adapter can accept a borrowed experimental hook;
the normal client still constructs it without one, so DeepFilter remains
unavailable there. A C++ test invokes the real adapter with a test WebRTC
interface stub and verifies selection, processing and return to browser mode.

The VAD delay line initially emitted previous audio after a stale result was
silenced. A regression reproduced this; resetting its state before processing
the silent frame prevented old samples from appearing in that and subsequent
frames. The publication/mute race after the callback still requires ownership
at the real track boundary; this component test does not prove that boundary.

The synthetic research probe used the real adapter with the same interface
stub, a separately hash-checked research DLL/model, and a prewarmed worker.
One three-second run submitted 300 frames, processed 297, and observed zero
fallbacks. It did not use the actual WebRTC library, microphone, network,
installed application, speech corpus or release assets. Device, quality,
sustained-runtime and signed-release acceptance remain NOT_RUN.

Windows `flutter build windows --release --no-pub` completed with local
Firebase C++ SDK 14.1.0. The source consisted of base commit
`6912f7b32e2801be6a4602b4e211c995d3b9f75a` plus this capture-hook change.
The unsigned runner SHA-256 was
`563f45e204213493bb6fd31feddc0faf19a3dbf58d76a1c153b990ec5cae862f`;
the `flutter_webrtc_plugin.dll` SHA-256 was
`b61293169e0743e465e61693733ba28a6a4aec28099c16cdc599619452e7375f`.
The build was not installed or launched and does not package libDF. Native
CTest passed 15/15; contracts and client parity checks passed separately.
