# Voice large-text component recheck

On reconciled source `e48a63bb1a7c325777f65bcf87864111be9b34a6`, the two
focused layout tests and 14 neighboring geometry tests passed on Windows.
These are Flutter component tests, not native-device or media acceptance.

Three synthetic component captures were inspected at source resolution:

| Capture | SHA-256 | Observation |
|---|---|---|
| 5 participants, 320x480, scale 2 | `3c265b459cf17ba723a76f7fe1150408f2ddfc6f39b06c14f0a5a04517990fd5` | Labels fit; later cards require scrolling. |
| 5 participants, 768x480, scale 2 | `a08726a6b4ddb4b6f8fcaa00ec12da95932e5e26af6ff9ec210e95a413531367` | One wide card fills most of the short viewport. |
| 10 participants, 1440x480, scale 2 | `e6484f29926a1db719ae1078dd3fa5f53d96bfed794bd6223f54cc07408df7a2` | Two cards appear in the first row; lower content requires scrolling. |

The focused test separately checks reaching the second card by scrolling.
The remaining capture gallery, Android/iOS runtime, screen reader, physical
devices, and media acceptance remain NOT_RUN.
