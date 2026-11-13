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

This is an incomplete notice draft, not a release manifest: audit transitive
Rust/WASM/native dependencies, include all applicable notices in each delivered
package, and verify distribution and signed rollback before release.
