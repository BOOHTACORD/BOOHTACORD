# Issue 687: native model prewarming

The native research worker now initializes the model on its own thread after
the requested generation starts, before the first audio frame. Readiness is
published only for the still-current generation. A failed initialization
reports failure without waiting for a frame; a test also changes generation
while initialization is blocked and confirms the older result is not accepted.

The capture hook distinguishes `awaiting-model`, `awaiting-audio` and model
failure through the existing failure-reason field. The application does not
yet wait for this readiness before creating or resuming a microphone track.
Mute/publish coordination and fallback integration remain release gates.

On this Windows x64 host, three separate synthetic runs of the locked static
CRT research DLL and model prepared before any audio in 316, 298 and 299 ms.
Each then submitted 300 frames, processed 297 and reported zero fallbacks.
A further run verified `awaiting-audio` after preparation and took 311 ms.
The tests use a stub WebRTC interface and prewarmed synthetic input; they do
not establish behavior on slower machines, real calls, cancellation during a
hung engine, speech quality or end-to-end latency. Repeated MSVC unit tests
also covered failed initialization and stale preparation across generations.

`flutter build windows --release --no-pub` succeeded using local Firebase C++
SDK 14.1.0 with base `398f54b94441e89f77abd77c9c19864ee866fef3` and the
prewarming changes. The unsigned runner SHA-256 was
`eef6eab3aaa0433cf0aa6a6ff48e509c0f180e83c9d4b0555ffd491fba07651d`,
and flutter_webrtc_plugin.dll SHA-256 was
`6061db9a33925f4df6be1bde8dae19f965b846f2d855443343af0e42d075f185`.
The build was not signed, installed, or launched; it does not deliver a
DeepFilter model or activate the experimental hook in the normal client.
