# Issue 687: third-party DeepFilterNet research

WorkAdventure/noise-suppression commit `7e00a1b7522f044a31776fddc249a97a98de94ed`
was checked in an isolated checkout, not integrated into BOOHTACORD. Its
prebuilt WASM SHA-256 was
`8ebf2b217b80fc128505b993c8d7d7d892df5a845ab7a2516fed74b76e7fe708`;
the bundled `DeepFilterNet3_onnx.tar.gz` SHA-256 was
`c94d91f70911001c946e0fabb4aa9adc37045f45a03b56008cb0c8244cb63616`.
The repository describes a libDF build based on DeepFilterNet commit
`d375b2d8309e0935d165700c91da9de862a99c31` plus its own tract patch.

The upstream `deepfilternet.browser.test.ts` suite reported 10/10 tests passed
in a locally selected Chromium executable on Windows. Startup logged failed
static-copy attempts for DTLN files; the DeepFilterNet tests completed despite
those errors. This is upstream-only evidence, not a BOOHTACORD browser or
native Windows test, and does not clear source provenance or dependencies.
At installation time `npm audit --omit=dev` reported one moderate protobufjs
advisory in that checkout; the full development dependency audit also reported
critical findings. The actual dependencies chosen for integration must be
assessed independently. No third-party dependency has been added to the app.

In the inspected worklet, `dispose` replaces the state handle with `undefined`;
there is no explicit model-free call on that path. The generated binding exposes
a raw `__wbg_dfstate_free` export but no public `df_destroy` API. Repeated nodes
on a borrowed AudioContext therefore require a proper ownership/free design and
measured lifecycle testing before integration; this observation alone does not
prove a leak in every context. The per-frame JS binding also allocates input
and output arrays, so its real-time cost must be measured rather than assumed.
The corresponding upstream Rust `wasm.rs` creates the handle with
`Box::into_raw`; no matching explicit destroy function is exposed there.

The official native `libDF` source at
`7b14b895fe7fc42cab72b4a4c1e49c982bd6404b` includes a C API, but its
`df_process_frame` uses `expect` on processing errors and the underlying
`DfTract::process` clones spectrum buffers in the per-frame path. The stock API
therefore cannot simply be connected to a callback that must avoid allocation
and aborts; allocation profiling and a bounded, failure-safe integration design
are still required.

A separate Windows x64 libDF research build used Rust 1.97.1, tract 0.21.4,
and an i7-12700. To avoid an unrelated HDF5 git checkout, its workspace and
optional dataset manifest entries were removed in the isolated checkout and
the lock was regenerated (SHA-256
`67fbef75860cff0812f4660f6f95d55bba942818f43dac1d20bbcf3a3043be02`).
The resulting DLL SHA-256 was
`4c9470b7d4b82e4c4a39b9c5683cfe0c593f15f203f464a471cc96e0553a0e4c`.
After 100 warmup frames, 1000 synthetic 480-sample calls through ctypes had
wall-time p50 0.6734 ms, p95 0.8113 ms, p99 0.8724 ms, max 1.1808 ms.
This includes wrapper overhead on one machine; it is not CPU utilization,
end-to-end delay, a 30-minute load test, allocation proof, or integration into
the native client. The altered manifests and generated DLL are not release
inputs. A future reproducible production build must pin and verify its own
unchanged sources and complete dependency graph.

An additional isolated rebuild inserted a counting Rust global allocator into
that checkout. Following 100 warmup frames, all 1000 synthetic `df_process_frame`
calls made allocations: 2154 observed `alloc`/`alloc_zeroed`/`realloc` calls per
frame in this experiment. This counts only allocations through the Rust global
allocator and includes instrumentation; it is not a complete heap profile.
It establishes that this specific build cannot satisfy a zero-allocation audio
callback contract by directly calling the stock processing function. The
instrumented library is not shipped or used by BOOHTACORD.

An independent fixed-capacity SPSC audio-frame queue was added as a possible
worker boundary. Its local C++ tests passed on Windows MSVC and Linux/WSL:
FIFO/overflow behavior, generation metadata, 10,000 ordered frames across two
threads, and no C++ `operator new` calls in the single-threaded queue operations.
The Linux test also passed with ThreadSanitizer. This does not cover arbitrary
allocators, more than one producer or consumer, deadlines, mute, or stale-frame
filtering: callers must enforce generation and failure policy. The queue is not
connected to libDF, WebRTC, microphone capture or a client setting.

Unknown: behavior on real capture, bounded fallback and mute, cross-browser
support, native Windows real-time integration, speech quality and latency.
