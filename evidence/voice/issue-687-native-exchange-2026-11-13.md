# Issue 687: native frame-exchange research

On Windows x64 with MSVC 19.44, the native CMake/CTest suite passed 9/9
tests, including the new fixed-capacity frame exchange and its allocation
probe. The probe exercised 1000 synchronous capture/worker exchanges and
observed no C++ `operator new` calls during those operations. It does not
observe other allocators or prove a realtime deadline.

Tests cover silence on underrun, invalid PCM and queue overflow, discarding
stale generations, mute, and identical input/output buffers. A controlled
two-thread test exchanges 10,000 frames in order; the existing queue test
separately exercises one producer and one consumer concurrently.
The exchange is not wired to libDF, WebRTC capture, or a Windows client.

A separate worker-step prototype was exercised with a fake engine. Tests cover
reset on generation changes, discarded stale inputs, engine errors and C++
exceptions, invalid output and a full output queue. Failed generations stay
disabled until a new generation. This does not exercise a Rust panic or real
libDF model, and it does not start or schedule a production worker thread.

The caller must advance the generation for mute, unmute and failure, reset
the model on generation changes, and synchronize publication with mute intent.
An overflow requires the owner to stop the pipeline and fall back; the test
does not claim self-recovery after an overflow. No result here proves those
owner responsibilities, fallback, production
thread scheduling, actual microphone quality, or end-to-end latency.
