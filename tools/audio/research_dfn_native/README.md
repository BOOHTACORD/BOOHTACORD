# Native DeepFilterNet research probe

`safe.rs` is an isolated C ABI experiment for the pinned libDF checkout; it is
not a supported production API. Its caller must uphold pointer validity,
ownership and exclusive thread access. Panic-abort behavior, dependencies,
licensing and a reproducible release build are unresolved.

With `BOOHTA_RNNOISE_TESTS=ON`, Windows CMake builds
`deepfilter_real_research_probe` and `deepfilter_threaded_research_probe`.
They are intentionally not automatic CTests:
the caller must supply absolute paths to an independently built research DLL
and model and check both hashes before execution. Do not run an unknown DLL.

The local experiment used DLL SHA-256
`8b79e0942e7e01e909ad3797e5c0ffa20296db41dce8a80bf67d6a440a860730` and
model SHA-256 `c94d91f70911001c946e0fabb4aa9adc37045f45a03b56008cb0c8244cb63616`.
These hashes identify this host's artifacts, not a release specification.
The threaded probe takes a final startup-frame argument from 0 to 4 and uses
synthetic 10 ms pacing on this host; any underrun is
reported and prevents treating it as a realtime acceptance. Neither probe
proves capture integration, fallback, acoustic quality or thread safety of
libDF in the actual client.
