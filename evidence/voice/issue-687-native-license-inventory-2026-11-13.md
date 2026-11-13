# Issue 687: native research dependency license inventory

On Windows, `cargo tree --locked --no-default-features --features capi -p
deep_filter --target x86_64-pc-windows-msvc --edges normal,build --prefix none
--format '{p}|{l}'` was run in the previously prepared DeepFilterNet native
research source. Cargo reported version 1.97.1; the Cargo.lock SHA-256 was
`67fbef75860cff0812f4660f6f95d55bba942818f43dac1d20bbcf3a3043be02`,
matching the native research preparation pin. Dependencies were fetched from
crates.io under Cargo's locked checksum verification. The offline attempt first
failed because the local cache lacked `backtrace`; the online run succeeded.

After deduplication, the target dependency tree contained 131 package/version
pairs and no blank license fields. Most declared MIT and/or Apache-2.0; other
declared expressions included CC0-1.0, BSD-2-Clause, Unlicense, Zlib and 0BSD.
`unicode-ident` 1.0.12 declared `(MIT OR Apache-2.0) AND Unicode-DFS-2016`.
The complete local command output is `.out/deepfilter-native-licenses.txt`,
SHA-256 `640e3671bf43f75ae139c50b1573fb66494458e833ed2179ad9b91059f27e9c8`.
All 131 pairs were matched against Cargo metadata and their packaged source
directories inspected for license or notice files. `crunchy` 0.2.2 and
`realfft` 3.3.0 declare MIT, but neither packaged source directory contains a
top-level license or notice file. Their exact notices require further review.

Follow-up: the `crunchy` 0.2.2 package records commit `1bf90cf2d0a8cfcb2c5592275a23ab028dff6468`;
the [matching upstream Cargo manifest](https://github.com/eira-fransham/crunchy/blob/1bf90cf2d0a8cfcb2c5592275a23ab028dff6468/Cargo.toml)
declares MIT. A later descendant commit `313e516a63d460ae504131ecbbd36aa971df6c83`
contains a complete MIT notice; its exact bytes were retained as a research draft,
SHA-256 `3eab77734a181b2a2e8418af9004f960f715f04aac4d76a26cf774f63a7b13d1`.
The `realfft` 3.3.0 package records commit `ed26ea38de34ce029f518beeccd7b83439016466`;
its README declares MIT. Descendant commit `9fdcf59c60c7ecacbf75774d378a068811a2e6ea`
adds a complete MIT notice, retained byte-for-byte as a draft, SHA-256
`080766c57f9e48f00218f4e43c7d671d4b6ffee85a39417b5ab3c916dfe29b0d`.
The later notices were absent at the two recorded package commits. Their
applicability and the actual release dependency graph still require review;
these drafts are not a completed distribution notice.

The corresponding Web research tree was inspected with the same command,
substituting `--features wasm --target wasm32-unknown-unknown`. Its Cargo.lock
SHA-256 was `83b27804cbfbe8167d62b2f839bf4d3bbd4adb1ea1deecc9b35c97ee6e98aa0b`.
It contained 123 package/version pairs; `unicode-ident` 1.0.27 declared
`(MIT OR Apache-2.0) AND Unicode-3.0`. The local command output is
`.out/deepfilter-web-licenses.txt`, SHA-256
`cfd3bfd536e0e75d1331b39c9c9cc60548733fe42842e8593d5614cc0273e8f0`.
WASM-filtered Cargo metadata matched 120 of these pairs; three host-side Windows
packages appeared only after inspecting unfiltered metadata. Among all 123,
`nom-language` 0.1.0, `tract-extra` 0.23.8 and `tract-transformers` 0.23.8
had no top-level packaged license/notice file. The two tract crates report a
dirty VCS source in their package metadata; upstream notices and exact source
provenance still need independent verification.
The MIT text from nom's repository root at the `nom-language` crate's recorded
commit is retained in the draft research notices.

Follow-up: both tract packages record upstream commit
`248335349c0f59a5772d737480b8b39250097374` as dirty. Git blob hashes matched
all packaged source files other than the manifests: two for `tract-extra`
and 20 for `tract-transformers`. Each `Cargo.toml.orig` differs from the
corresponding committed manifest only in changing `0.23.8-pre` to `0.23.8`;
packaged Cargo.lock files and Cargo-generated normalized manifests were not
compared by this check. The upstream commit's root `LICENSE` and `LICENSE-MIT`
are retained byte-for-byte in the Web research notice directory, SHA-256
`f7ef673bf046d823dcd775bdd0768432bd8855f81d0e5e1290a0a48c42e2dca3` and
`23f18e03dc49df91622fe2a76176497404e46ced8a715d9d2b67a7446571cca3`.
This narrows the source discrepancy but is not a complete release audit.

This tree includes normal and build dependencies and is an inventory of Cargo
metadata, not a complete review of distributed files or license texts. Audit
the actual release graph, non-Rust dependencies and compound conditions, then
bundle the required notices. No production binary or release was approved.
