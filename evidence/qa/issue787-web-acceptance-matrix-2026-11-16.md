# Issue #787 — Web acceptance matrix retest (2026-11-16)

## Scope

Retested the merged Web screen-viewer UX and the registered `screen` Web feature on `origin/master` at `6003eb940edea07e183a805c333272f7385cbb57`. Added one focused browser case for the issue's six-participant roster count. No runtime behavior, transport, or server contract changed.

## Verification

- `npm run test:screen-share-ui`: **58 passed**. Covers 320/390/640/720/1024/1440 viewports, 200% text/zoom, roster layout and keyboard focus, 1/4/6/20 participants, 1/2/8 streams, preview states, toolbar, statistics freshness and touch.
- `npm run test:mini-player`: **24 passed**.
- Registered command:
  `BOOHTACORD_QA_EGRESS_PLATFORM=linux/amd64 ./tools/qa/local_features/check.sh --feature screen --platform web --base origin/master --real-stack`
- Registered run report: `.out/local-features/20261116-121451/report.json`.
  - Web unit: **583 files / 2,015 tests passed**.
  - Web build: **PASS**.
  - Accessibility: **115 passed**.
  - Mini-player: **24 passed**.
  - Screen share UI: **58 passed**.
  - Real-stack Web lifecycle: **PASS** at 1440 and 393 px; source-stability: **PASS**.
  - Overall: **BLOCKED** only because `web-screen_profile` skipped one gated publisher/viewer baseline test. It requires short-lived publisher/viewer tokens and explicit confirmation of an isolated test SFU; the generic feature runner does not supply these inputs.
- Without the documented `linux/amd64` Egress override, Docker could not start the pinned host-native image because it lacked the configured `egress` user. The documented override allowed both real-stack viewport runs to pass.

The 1440/393 real-stack logs include server preview refresh, screen descriptor HTTP 204, seven sender telemetry POSTs HTTP 204, and one selected-viewer `screen_telemetry.updated` event. This confirms the paired Web path in the owned test stack; it is not physical-device or capacity evidence.

## Source-resolution visual review

Reviewed the selected PNGs at their native pixel dimensions under `.out/local-features/20261116-121451/images/web-screen_share_ui/`:

| Capture | Dimensions | SHA-256 | Observation |
| --- | ---: | --- | --- |
| `disclosure.browser-partici-d9f1b--roster-into-a-compact-grid/viewer-participants-four-320-100.png` | 320×900 | `534e0e0967a6ecd3cdc6c34eb286ebfa4ea62280ca53c959b1ee3316f13113a4` | One-column roster; controls remain inside the narrow stage. |
| `disclosure.browser-partici-d9f1b--roster-into-a-compact-grid/viewer-participants-four-390-200.png` | 390×900 | `84c0fe1b64dfba16d7e638c7efe961231f43895919f7e8606099f54d1d5b3d34` | One-column roster at 200% text; long names wrap and the list stays in its panel. |
| `disclosure.browser-partici-d9f1b--roster-into-a-compact-grid/viewer-participants-four-720-100.png` | 720×900 | `a916bbe7ac0912cf9e72420fabd3e5dc58e81cbf79ec5964cdc8b138bd011aa7` | Two-column roster with sufficient card width. |
| `disclosure.browser-partici-d9f1b--roster-into-a-compact-grid/viewer-participants-four-1024-100.png` | 1024×900 | `29c68b1ad27e01c4785cae5456e7383bc52e3d941580cf147fde3c1e4a798418` | Two-column roster remains bounded to the viewer stage. |
| `disclosure.browser-partici-d9f1b--roster-into-a-compact-grid/viewer-participants-four-1440-100.png` | 1440×900 | `c6f433b70b524cc58944b64016ff5f5460b96b730560352051c05299545c5f7d` | Two-column desktop roster; video stage remains visible. |
| `disclosure.browser-six-par-f681e-ithout-horizontal-scrolling/viewer-participants-six-720.png` | 720×900 | `e291850d8fa0fa176a03307e11b852c6222ea66f10400103937fe8532a15a0c2` | Six participants fit two columns with no horizontal overflow. |
| `disclosure.browser-large-p-d9e88-p-without-widening-the-page/viewer-participants-20-720.png` | 720×900 | `31249d5cea3f09c8f8270ca4da089176972e7bc7cba49f942487066e8ebd8f73` | Twenty participants remain in the internal scrolling grid. |
| `compact.browser-many-strea-2addc-internal-vertical-scrolling/stream-switcher-eight-mobile.png` | 390×844 | `fd612c6d478a425ef48124a18f9843613f9b96dae0c8e33b33dd5d257630b541` | Eight streams use one column and scroll inside the popover. |
| `disclosure.browser-selecte-9fb92-es-from-server-receipt-time/sender-telemetry-393.png` | 393×900 | `2bebc6712f68737f2b63b82c3fe5875370e6c3d58b52ed08c0428fa30d175ae4` | Receiver and sender summaries are separate; details continue in the panel's vertical scroll. |

Also reviewed the owned real-stack `screen-share-compact-statistics.png` captures at native dimensions: 1440 viewport = 2880×1800, SHA-256 `02c3a07da38a0dc51d7dbf829f1841a966af05e2d733cf733723b55e6223a55a`; 393 viewport = 1179×2556, SHA-256 `f22cbc303d7341ce3dd8cdc37822b18a65b7b45a81420f9bd8388a84eb70ef00`. Both show receiver measurements separately from sender measurements and configured target; the taller mobile details panel scrolls vertically. These images are test-stack evidence, not a physical display or hardware-quality claim.

## Remaining acceptance status

- `web-screen_profile` numeric publisher/viewer baseline: **BLOCKED** by the gated skipped test above.
- Flutter Android/iOS/macOS/Windows paired sender → Web, native capture-picker, and physical-device visual/media checks: **NOT_RUN**.
- Hardware media-quality and load/capacity evidence: **NOT_RUN**.

Issue #787 remains open until the remaining platform and release acceptance gates have evidence.
