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

An explicitly invoked Windows research probe then used the isolated C ABI and
the actual libDF model with this exchange and worker step for 220 synthetic
frames, then muted and reset for a new generation. It passed with DLL SHA-256
`8b79e0942e7e01e909ad3797e5c0ffa20296db41dce8a80bf67d6a440a860730` and
model SHA-256 `c94d91f70911001c946e0fabb4aa9adc37045f45a03b56008cb0c8244cb63616`.
This synchronous experiment is not a production build, microphone, worker
scheduling, long-duration, latency, fallback or speech-quality test.

In a separate approximately three-second synthetic run, a worker thread
initialized and processed the same model while the caller paced 300 frames at
10 ms. It observed 297 ready frames, 3 underruns and 0 overloads; 298 frames
had been processed when the worker stopped. This is a smoke experiment, not
an end-to-end latency or 30-minute acceptance. The underruns are a NO-GO for
claiming a stable realtime pipeline; their cause has not been established.
In subsequent single short runs, the same probe observed: no startup buffer,
297 ready / 3 underruns; two startup frames, 297 ready / 1 intentional
buffering / 2 underruns; four startup frames, 297 ready / 3 intentional
buffering / 0 underruns. One frame was primed before each timed loop. These
are exploratory observations, not a validated buffer choice or a measured
end-to-end delay. No setting has been enabled in the client.

After adding sequence diagnostics, another set of single three-second runs
reported p95 and maximum of four frame intervals for all three settings; the
same ready/buffering/underrun counts were observed. The nominal pacing was
10 ms per frame, but frame-index lag excludes model lookahead and real capture,
transport and playout. It cannot establish the issue's 80 ms end-to-end limit.

The caller must advance the generation for mute, unmute and failure, reset
the model on generation changes, and synchronize publication with mute intent.
An overflow requires the owner to stop the pipeline and fall back; the test
does not claim self-recovery after an overflow. No result here proves those
owner responsibilities, fallback, production
thread scheduling, actual microphone quality, or end-to-end latency.
