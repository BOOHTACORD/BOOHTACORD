# Issue 689: browser lifecycle scenario refactor

- Source at execution: HEAD `72928320db20baa1ca7c9810d5a7bafe7e8a7533`, dirty worktree SHA-256 `aaecc8579a45cbe0d6f9c353852990a4ec26756f38763baf8f7cbc066b1151ec`; source stability passed separately at both widths. This is not an immutable release build.
- The scenario was split into a dedicated `journey` leaf; runtime checks, ordering and composer visibility assertion were preserved. The runner now fingerprints all files in that leaf. Thirty lifecycle tests, 14 QA selection/policy tests and syntax checks passed.
- Browser lifecycle against owned local Go/PostgreSQL/Caddy/Tempo services passed for 1440 and 393 CSS-pixel widths; the report says owned resources removed. The noncritical fixture did not start LiveKit, so its roster unavailable/stale status is expected and does not validate healthy SFU behavior. This does not replace the full registered feature gate.
- Two screenshots per width were inspected individually at their original raster: the log composer and message actions remain inside the viewport. The opened action menu overlays some message text on mobile, as captured. Remaining screenshots were not visually reviewed; no baseline was approved.

## Reviewed screenshots

- `1440/channel-log.png`: 2880×1800, SHA-256 `6b6e558abd2ab3ee5897c6b7e5540f08b8cd2c9d7d3da6c9a403006c5d231999`
- `1440/channel-text-actions.png`: 2880×1800, SHA-256 `ec05612ded59e54239c4ef04a5f3f98f277171d15824bd553b5cb6bae35549c1`
- `393/channel-log.png`: 1179×2556, SHA-256 `a1287f9b11061e3fd583863e55bf0e3cacb5f2be40c2c6b4fc7226f5d2bb37c6`
- `393/channel-text-actions.png`: 1179×2556, SHA-256 `179d7aaab90a54c9eccfe7a03408fd6666c24be7fae27f62c5d4f9b73d188d54`
