# Issue #787 PR 3: Web viewer toolbar — 2026-11-16

**Scope:** Web screen-viewer toolbar semantics and narrow-screen audio controls. The viewer exposes a single neutral action to return to participants, distinguishes local playback pause from stopping a broadcast, keeps browser fullscreen separate from app-area expansion, and provides a compact volume popover on narrow stages. Only the owner can stop their own broadcast.

## Results

- Focused `screen_share_ui` Playwright suite: **PASS** (54/54).
- Focused `mini_player` Playwright suite: **PASS** (24/24).
- Focused viewer presentation Vitest checks: **PASS** (26/26).
- Web production build with `VITE_PUBLIC_ORIGIN=https://v.bootybay.ru`: **PASS**. The build emitted the existing LiveKit dynamic-import and chunk-size warnings.
- Local feature run `.out/local-features/20261116-020547/index.html`: overall **BLOCKED**. Web unit, build, accessibility, all selected browser scenarios, and source-stability checks passed. Both real-stack viewport runs passed (`web-real-stack-1440=PASS`, `web-real-stack-393=PASS`). `web-screen_share_ui=PASS`.
- The only blocked stage was `web-screen_profile`: 18 passed and one existing publisher/viewer baseline test was skipped (`tests/screen_profile/baseline.browser.spec.ts:28`). This is not evidence of a media or capacity failure; it remains an unproven media baseline.

## Visual review

Reviewed the current local-feature screenshots at source resolution (320 × 844 and 390 × 844). In both captures the volume popover remains inside the viewer stage, its range track is compact, the mute action is legible, and the toolbar remains visible beneath it. The interaction tests also verify Escape dismissal and focus restoration. These captures use the browser fixture's first-frame placeholder; they verify layout and controls, not media quality.

Artifacts:

- `.out/local-features/20261116-020547/images/web-screen_share_ui/compact.browser-narrow-vie-f2c34-nd-restores-focus-on-Escape/viewer-volume-popover-320.png`
- `.out/local-features/20261116-020547/images/web-screen_share_ui/compact.browser-narrow-vie-f2c34-nd-restores-focus-on-Escape/viewer-volume-popover-390.png`
- Full local-feature report: `.out/local-features/20261116-020547/index.html`

No media-capacity or device-quality claim is made by this evidence record.
