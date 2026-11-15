# Issue #787 — adaptive Web roster and popup

**Scope:** PR1 only, the Web participant roster and popup behavior. This is one leaf of the issue's split work; other UX/telemetry work, native clients, and release gates are not closed by this record.

## Results

- Focused Web unit test, TypeScript check, and production build: **PASS**. The build emitted the existing dynamic-import and large-chunk warnings.
- Focused `screen_share_ui` Playwright behavior: **PASS**. Covered 320, 390 at 200% text, 640, 720, 1024, and 1440 CSS-pixel viewports; a 400 CSS-pixel viewer container inside a wide viewport; keyboard open, Escape and focus return; long-name accessible label/title/tooltip; and a 20-person internally scrolling roster.
- Local API/LiveKit browser lifecycle at 1440 and 393 CSS pixels: **PASS** with the documented `BOOHTACORD_QA_EGRESS_PLATFORM=linux/amd64` Egress fallback. Both runs reported `Actual browser lifecycle PASS` and removed their owned resources.
- Full selected local-feature run: **BLOCKED/FAIL as a complete gate**. The registered Web unit/build/browser suites passed except `web-screen_profile`, which remains BLOCKED because one isolated publisher/viewer test is skipped. The host-native Egress image also failed its startup check (`egress` user unavailable); the direct 1440/393 lifecycle runs passed using the documented Egress fallback. Reports: `.out/local-features/20261115-103211/` and `.out/local-features/20261115-104119/`.
- Android/iOS acceptance and load/capacity evidence: **NOT_RUN**. This Web UI change makes no native, media-quality, or capacity claim.

## Visual review

Reviewed the browser captures at source resolution. At 320 CSS px the participant cards stay in one column and within the viewer; at 390 CSS px with 200% text the names wrap/clamp while the accessible full name remains available, and the close control remains reachable. At 720 and 1440 CSS px the four-card roster uses two columns with distinct speaking, screen-share, watcher, and microphone states. The 20-person capture shows the roster scrolling inside the popup while the popup width and page remain fixed. No horizontal roster/page overflow or card collision was visible.

Artifacts are under `.out/issue348/browser/`, including `viewer-participants-four-{320-100,390-200,640-100,720-100,1024-100,1440-100}.png` and `viewer-participants-20-720.png`.
