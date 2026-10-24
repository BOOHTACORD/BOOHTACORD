# Global Web scrollbar styling — 2026-10-24

## Change

All Web scroll surfaces now use a thin 6px rounded thumb and a transparent track. The thumb uses the dark subtle-border color by default and only brightens to the neutral control-border color on hover. It does not use accent or side glow states. Firefox receives matching `scrollbar-color` and `scrollbar-width` values; WebKit browsers receive custom track, thumb and corner styles.

## Evidence

- The new browser regression failed before implementation because the navigation scrollbar resolved to the browser default (`scrollbar-color: auto`).
- Navigation density browser suite: **25/25 PASS**, including checks for the production navigation rail and an independent scroll container, resolved theme colors, thumb width/radius, transparent track, and neutral hover state.
- The updated `web-scrollbar-themed.png` and `web-scrollbar-hover.png` screenshots were reviewed at source resolution. This headless browser hides overlay scrollbar pixels in screenshots, so visual appearance is verified through the computed-style assertions; the images still confirm the surrounding layout is unchanged.
- Local Web acceptance for the dependent `auth`, `connection_status`, `screen`, `shell`, and `voice` features: all **24 stages PASS**, including real-stack runs at 1440px and 393px. The generated aggregate report is `REVIEW_REQUIRED` because its gallery contains captures from many unrelated features; only the scrollbar-specific captures were reviewed for this change.
- Client parity verifier, JSON validation and `git diff --check`: **PASS**.
- Native runtimes: **NOT_RUN**; this is a Web-only style change.

## Limits

The browser regression checks computed WebKit/Chromium styles and the shared CSS values. It does not establish how each operating system chooses to display overlay scrollbars or prove physical-device behavior.
