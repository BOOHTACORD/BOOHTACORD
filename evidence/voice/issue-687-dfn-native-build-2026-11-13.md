# Issue 687: instrumented native DeepFilter build

The isolated source preparation uses upstream commit
`7b14b895fe7fc42cab72b4a4c1e49c982bd6404b`, checks the model SHA-256
`c94d91f70911001c946e0fabb4aa9adc37045f45a03b56008cb0c8244cb63616`,
and applies the tracked research ABI and allocation counter. The locked
dependency manifest has SHA-256
`67fbef75860cff0812f4660f6f95d55bba942818f43dac1d20bbcf3a3043be02`.
The source preparation rejects unexpected layout, a different commit or an
existing output directory. It does not authenticate the local Git repository.

On Windows x64, Rust 1.97.1 / Cargo 1.97.1 and MSVC 19.44, two separate
offline `cargo build --release --locked --offline --no-default-features
--features capi -p deep_filter` builds succeeded. Their DLL SHA-256 values were
`4ddbced782466572991d7b46a860df5d96fb2795f6b5c6d5ee95664f793b2b64` and
`af1d9c296a6b73a1874e5b5d1074e8e46b8070980d53d38bcac822b968cae40a`.
They were not byte-identical: the observed differences included PE timestamps
and a PDB identifier. The older instrumented DLL and first new build produced
identical 220-frame synthetic float32 output SHA-256
`b4434f116dcba858fa827d3ffbb566e297b3adff543bf7f7c4a52d45c5d67a1b`.
This compares one synthetic fixture, not speech quality or compatibility.

With `RUSTFLAGS='-C link-arg=/Brepro'`, two further builds from the same source
path into separate target directories produced byte-identical DLLs, both SHA-256
`36eb338789a6be237b8f8b142d16b36b87d5d09d2beb99d46c97008358003356`.
Their 220-frame synthetic output hash matched the first build above. This is a
same-machine, same-source-path observation, not cross-machine reproducibility.

An additional source tree prepared with `--without-allocation-counter` built
with the same locked dependencies and linker flag. Its first DLL SHA-256 was
`d94350604128a9e01641b0ed5600969c48908846a6d5fdc414361a500f11b254`.
An independent second target directory on the same host and source path
produced an identical DLL and identical synthetic output fingerprint.
The research workflow now defines a Windows job that repeats these builds and
fingerprints; its hosted result is not yet available.
Its exports included create/process/free and omitted the research allocation
counter. The same 220-frame synthetic fingerprint matched the instrumented
variant, and one prewarmed capture-adapter smoke submitted 300 frames with
297 processed and zero fallback. This variant also remains research-only.

The [upstream pinned license statement](https://github.com/Rikorose/DeepFilterNet/blob/7b14b895fe7fc42cab72b4a4c1e49c982bd6404b/README.md#license)
offers MIT or Apache-2.0 for repository code and weights. A local offline
`cargo tree --edges normal,build` review found 131 unique package/version and
declared-license rows, including Unicode-DFS-2016 alongside MIT/Apache choices.
The local tree artifact SHA-256 is
`053955eabfeaf33d26c64c28b7fe860cab3f7847fd5a0c408839cd9967661a59`.
Manifest license declarations are not a complete notice or provenance audit;
third-party notices and release compliance remain unverified.

The research build includes a counting allocator and is not suitable for
delivery; the noninstrumented variant has also not passed release acceptance.
Neither establishes signed binaries, real-time deadlines, absence
of hangs, user-device acceptance, or integration with an installed client.
