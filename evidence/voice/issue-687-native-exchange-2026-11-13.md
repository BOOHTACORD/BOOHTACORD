# Issue 687: native frame-exchange research

On Windows x64 with MSVC 19.44, the native CMake/CTest suite passed 7/7
tests, including the new fixed-capacity frame exchange and its allocation
probe. The probe exercised 1000 synchronous capture/worker exchanges and
observed no C++ `operator new` calls during those operations. It does not
observe other allocators or prove a realtime deadline.

Tests cover silence on underrun, invalid PCM and queue overflow, discarding
stale generations, mute, and identical input/output buffers. The existing
queue test separately exercises one producer and one consumer concurrently.
The exchange is not wired to libDF, WebRTC capture, or a Windows client.

The caller must advance the generation for mute, unmute and failure, reset
the model on generation changes, and synchronize publication with mute intent.
No result here proves those owner responsibilities, fallback, production
thread scheduling, actual microphone quality, or end-to-end latency.
