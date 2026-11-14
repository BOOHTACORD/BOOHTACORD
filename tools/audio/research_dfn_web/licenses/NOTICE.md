# DeepFilterNet3 research notice preparation

The research bundle derives from DeepFilterNet commit
`d375b2d8309e0935d165700c91da9de862a99c31` and uses a model whose bytes also
appear at upstream commit `7b14b895fe7fc42cab72b4a4c1e49c982bd6404b`. The
later upstream README explicitly offers MIT or Apache-2.0 for code and model
weights; this notice prepares the MIT option. The included `DEEPFILTERNET-MIT.txt`
matches the MIT license at both commits, SHA-256
`24e6bb09c928af8d8e56268082f87413247ce36b39dd5d33add2f9893968065e`.

The Web research builder also applies a patch from WorkAdventure/noise-suppression
commit `7e00a1b7522f044a31776fddc249a97a98de94ed`. Its original MIT license is
included as `WORKADVENTURE-MIT.txt`, SHA-256
`8799c8bada86a11bbe34ece32c6bc4b3ea352b881911f79466537188a322cfa8`.

`nom-language` 0.1.0 declares MIT but its published crate has no top-level
license file. `NOM-MIT.txt` retains the repository-root MIT text at the crate's
recorded source commit `2cec1b3e4c9ccac62c902d60c00de6d1549ccbe1`, SHA-256
`4dbda04344456f09a7a588140455413a9ac59b6b26a1ef7cdf9c800c012d87f0`.

The published `tract-extra` and `tract-transformers` 0.23.8 packages report
dirty source at `248335349c0f59a5772d737480b8b39250097374`. Their packaged
source files match that commit; their original Cargo manifests differ in the
version suffix. `TRACT-NOTICE.txt` and `TRACT-MIT.txt` retain the root license
files from that commit. Packaged lockfiles and the actual release dependency
graph still require review; see the native license inventory evidence.

The native and Web research trees respectively include `unicode-ident` 1.0.12
and 1.0.27 with additional Unicode license conditions. Their packaged Unicode
license texts are retained as `UNICODE-IDENT-1.0.12.txt` (SHA-256
`68f5b9f5ea36881a0942ba02f558e9e1faf76cc09cb165ad801744c61b738844`) and
`UNICODE-IDENT-1.0.27.txt` (SHA-256
`f7db81051789b729fea528a63ec4c938fdcb93d9d61d97dc8cc2e9df6d47f2a1`).
The shared MIT option is in `UNICODE-IDENT-MIT.txt`, SHA-256
`23f18e03dc49df91622fe2a76176497404e46ced8a715d9d2b67a7446571cca3`.
Whether these build dependencies contribute code to the final artifacts must
be established during the release graph audit.

This is an incomplete notice draft, not a release manifest: audit transitive
Rust/WASM/native dependencies, include all applicable notices in each delivered
package, and verify distribution and signed rollback before release.
