# Native DeepFilterNet research probe

`safe.rs` is an isolated C ABI experiment for the pinned libDF checkout; it is
not a supported production API. Its caller must uphold pointer validity,
ownership and exclusive thread access. Panic-abort behavior, dependency notice
delivery and a reproducible release build are unresolved.

An instrumented **research** source tree can be recreated from a local upstream
Git repository containing commit `7b14b895fe7fc42cab72b4a4c1e49c982bd6404b`:

```powershell
python -m tools.audio.research_dfn_native.prepare --source <upstream-repo> --output <new-directory>
```

In that directory, using the pinned Cargo.lock and a populated Cargo cache:

```powershell
$env:RUSTFLAGS='-C link-arg=/Brepro'
cargo build --release --locked --offline --no-default-features --features capi -p deep_filter --target-dir <new-build-directory>
```

Two separate instrumented builds on the same Windows machine and source path
were byte-identical with that linker flag. This is not proof of reproducibility
across source paths, machines, compiler versions or a release pipeline.

The preparation checks the upstream model hash and refuses source-layout drift.
It removes unused workspace/HDF5 dependencies and injects `safe.rs` and the
counting `alloc.rs`; the latter makes this an instrumented experiment, not a
release build. Pass `--without-allocation-counter` to prepare a separate tree
without the counting allocator. That variant is still research-only until
licensing, provenance, failure handling and device acceptance are complete.
The command does not download or authenticate an upstream checkout.
`python -m tools.audio.research_dfn_native.fingerprint --dll <path>
--dll-sha256 <expected> --model <path>` prints a hash of synthetic output after
checking the DLL and model. Use only trusted local artifacts. The preparation
and fingerprint tests run in the audio research CI workflow.

With `BOOHTA_RNNOISE_TESTS=ON`, Windows CMake builds
`deepfilter_real_research_probe` and `deepfilter_threaded_research_probe`.
They are intentionally not automatic CTests:
the caller must supply absolute paths to an independently built research DLL
and model and check both hashes before execution. Do not run an unknown DLL.
`deepfilter_capture_hook_research_probe` additionally uses the native capture
adapter with a stub WebRTC interface; it does not run the installed client.

The threaded probe converts S16-scale WebRTC-style PCM through the experimental
capture bridge before worker processing. It does not use the client capture hook.
The local experiment used DLL SHA-256
`8b79e0942e7e01e909ad3797e5c0ffa20296db41dce8a80bf67d6a440a860730` and
model SHA-256 `c94d91f70911001c946e0fabb4aa9adc37045f45a03b56008cb0c8244cb63616`.
These hashes identify this host's artifacts, not a release specification.
The threaded probe takes a final startup-frame argument from 0 to 4 and uses
synthetic 10 ms pacing on this host; any underrun is
reported and prevents treating it as a realtime acceptance. Neither probe
proves capture integration, fallback, acoustic quality or thread safety of
libDF in the actual client.
