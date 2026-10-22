# Web screen viewer controls — 2026-10-21

**Scope:** Direct controls over a selected screen share: expand or collapse the viewer, exit browser fullscreen without Escape, and stop watching a remote stream.

## Follow-up — 2026-10-22

- Regression coverage now checks that the overlay fades after entering browser fullscreen, including when the expand button retains mouse focus. It also checks narrow hover-capable layouts. Moving the pointer over the stage reveals the actions again.
- Final `screen_share_ui` Playwright suite: **PASS** (26 tests), including the fullscreen idle-hide, narrow-window and keyboard-focus regressions. Web unit/build/accessibility, all selected Web browser suites, Flutter unit tests and Flutter component captures: **PASS**.
- Real API/SFU scenarios: **FAIL during environment setup** because the configured Colima Docker socket `/Users/pistol121/.colima/boohtacord-qa/docker.sock` is unavailable. Android/iOS runtime checks remain **BLOCKED**. The complete local-feature report is therefore **FAIL** and its full visual review remains **NOT_RUN**.
- Reviewed the four relevant captures from `.out/local-features/20261022-205401` at their source resolution. In the 1280 × 800 idle capture the stage is unobstructed; the fullscreen captures keep both actions within the lower-right stage overlay. At 390 × 844 and 200% text, both labels wrap inside the overlay without horizontal page overflow. These are synthetic fixture captures with a first-frame placeholder, not live-media evidence.
- Full local-feature report: `.out/local-features/20261022-205401/index.html`.

## Results

- Focused Playwright behavior and layout checks: **PASS** (2 scenarios). The browser test confirmed app-level expand/collapse, the in-stage fullscreen exit, and stopping a remote stream while fullscreen is active.
- Pointer-reveal behavior: **PASS**. On desktop the action panel starts hidden, appears on pointer movement/press, then fades and slides down after 1.8 seconds without activity. Keyboard focus keeps it visible; touch layouts keep it available.
- Focused screen presentation Vitest checks: **PASS** (16 tests).
- Local feature Web unit tests, production build, accessibility and all selected browser suites: **PASS**, including all 25 `screen_share_ui` tests, `mini_player`, and `voice_interface`.
- Real API/SFU checks at 1440px and 393px: **FAIL during environment setup**. Docker context `colima-boohtacord-qa` is selected, but `docker buildx` is unavailable (`docker: unknown command: docker buildx`). No live publisher/viewer session was created.
- The broad local-feature report leaves overall visual review as **NOT_RUN** because it contains captures outside this change. The four viewer-control captures below were reviewed separately at source resolution.

## Visual review

- `viewer-controls-expanded.png` (1280 × 800): the expand/collapse and stop-viewing buttons sit in a translucent panel at the lower-right of the stage; both labels and focusable controls remain distinct from the stream label.
- `viewer-controls-browser-fullscreen.png` (1280 × 800): the overlay remains inside the fullscreen stage and exposes collapse, return-to-window, and stop-viewing actions.
- `viewer-controls-idle-hidden.png` (1280 × 800): the action panel is absent while the pointer is idle; the video stage remains unobstructed.
- `viewer-controls-mobile-text-200.png` (390 × 844): the overlay wraps to two rows at 200% text and stays within the viewport without horizontal document overflow.

These captures use the synthetic browser fixture and show its first-frame placeholder, not live media. They verify control placement and browser behavior only.

Artifacts:

- `.out/issue348/browser/disclosure.browser-screen--71ff0-ullscreen-and-stop-watching/viewer-controls-expanded.png`
- `.out/issue348/browser/disclosure.browser-screen--71ff0-ullscreen-and-stop-watching/viewer-controls-browser-fullscreen.png`
- `.out/issue348/browser/disclosure.browser-screen--71ff0-ullscreen-and-stop-watching/viewer-controls-idle-hidden.png`
- `.out/issue348/browser/disclosure.browser-screen--3d7a3-narrow-viewport-at-200-text/viewer-controls-mobile-text-200.png`
- Full local-feature report: `.out/local-features/20261021-225802/index.html`
