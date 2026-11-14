# Issue 687: DeepFilterNet3 model license provenance

On 2026-11-13, the official DeepFilterNet repository at commit
`7b14b895fe7fc42cab72b4a4c1e49c982bd6404b` stated that code and model
weights in that repository are dual licensed under MIT or Apache-2.0, at the
recipient's option: [upstream README](https://github.com/Rikorose/DeepFilterNet/blob/7b14b895fe7fc42cab72b4a4c1e49c982bd6404b/README.md#license).
The original research source pin `d375b2d8309e0935d165700c91da9de862a99c31`
described its code as dual licensed but did not explicitly mention weights.

The official `models/DeepFilterNet3_onnx.tar.gz` was retrieved at the later
commit and hashed without writing it into the repository. Its 7,983,136 bytes
have SHA-256 `c94d91f70911001c946e0fabb4aa9adc37045f45a03b56008cb0c8244cb63616`,
matching the model pinned for the research bundle. This is evidence that the
same model bytes appear in the repository whose later README explicitly covers
model weights; the repository statement is not an audit of every transitive
dependency in our eventual distribution.

The research notice draft prepares the MIT option and retains the exact upstream
MIT license texts for DeepFilterNet and the WorkAdventure patch under
`tools/audio/research_dfn_web/licenses`. It is not yet a bundled release notice
or a complete third-party inventory. Signed delivery and release approval remain
open. RNNoise v0.2 is a
separate model: its weights license remains unconfirmed, as tracked in
[upstream issue 284](https://github.com/xiph/rnnoise/issues/284).
