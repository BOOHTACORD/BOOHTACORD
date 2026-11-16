# Issue #787 PR4 — Web diagnostics presentation

Date: 2026-11-16
Base: `master` at `cf08af34220ba2f258d47b140ca14096e823413e`
Local feature report: `.out/local-features/20261116-035331/`
Report source identity: `cf08af34220ba2f258d47b140ca14096e823413e`, worktree SHA-256 `11655ed1f39faf0b3ccccec7635a40de6a44867a9ceead3ee6c1f3388218a57e`.

## Scope

This record covers PR4’s compact Web screen-viewer diagnostics, disclosure details, and truthful receiver-side measurements. Sender telemetry relay, Flutter sender integration, cross-platform capability evidence, and device media quality remain in PR5–PR7 scope.

## Checks

| Check | Result |
| --- | --- |
| `npm test --` in `clients/web` | PASS — 581 files, 2,002 tests |
| `VITE_PUBLIC_ORIGIN=https://v.bootybay.ru npm run build` | PASS |
| `npx playwright test -c tests/screen_profile/metadata_diagnostics.playwright.config.ts` | PASS — 4 tests |
| `npx playwright test -c tests/track_name/playwright.config.ts` | PASS — 2 tests |
| `npx playwright test -c tests/screen_share_ui/playwright.config.ts` | PASS — 56 tests |
| `python3 -m tools.verify.client_parity.run --base origin/master` | PASS |
| Registered Web local-feature suite, including `web-unit`, `web-build`, `web-accessibility`, `web-screen_share_ui`, `web-track_name`, `web-real-stack-1440`, `web-real-stack-393` | BLOCKED overall; all listed stages PASS except `web-screen_profile` |
| `web-screen_profile` isolated publisher/viewer baseline | BLOCKED — one test skipped because `SCREEN_BASELINE_LIVEKIT_URL`, short-lived publisher/viewer tokens, and `SCREEN_BASELINE_TARGET=isolated-test` were not supplied |
| `source-stability` for the registered local-feature run | PASS |

The local-feature report is `.out/local-features/20261116-035331/index.html`; its machine-readable status is BLOCKED only for the isolated publisher/viewer baseline skip. Both authenticated disposable real-stack viewports completed successfully. The 1440 px and 393 px lifecycle each verified a decoded screen stream, the selected viewer, current receiver presentation, honest track-name profile provenance, explicit unavailable sender measurements/configuration status, and clean viewer stop while voice remained connected. These runs do not provide physical-device or media-capacity evidence.

Hosted contracts/CI have not run yet; they are pending the PR. The change does not modify OpenAPI, realtime schemas, Go/API contracts, or Flutter/native code.

## Visual review

Inspected the final report screenshots at their source resolution:

- `web-screen_share_ui/.../receiver-diagnostics-320.png`: the narrow diagnostics panel scrolls vertically within its viewport; receiver, sender, configuration, and unavailable data stay separated without horizontal overflow.
- `web-screen_share_ui/.../receiver-diagnostics-1440.png`: the summary stays compact and the expanded details use the available two-column layout; values and units remain aligned.
- `web-screen_share_ui/.../receiver-text-200-1024.png`: increased text remains legible and wraps within the panel; words and values are not clipped.
- `web-real-stack/393/screen-share-compact-statistics.png`: the phone bottom sheet keeps the receiver and sender summaries readable. The sender profile is explicitly labelled as derived from the legacy track name, and sender measurements remain unavailable.
- `web-real-stack/1440/screen-share-compact-statistics.png`: the desktop summary shows actual receiver resolution while leaving FPS unavailable where no measured value exists; it does not promote the 720p/30 target to an actual measurement.

The deterministic UI fixture separately verifies measured decoded FPS, bitrate, packet-loss window, and RTT labels. Those fixture values are presentation coverage, not a media-quality or capacity claim.
