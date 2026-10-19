# Android Web touch push-to-talk

**Scoped Web acceptance:** PASS for the registered touch PTT UI and activation behavior. No physical-device microphone or media-quality claim.

The final local feature run is `.out/local-features/20261019-161809` (base `3dc9d5929d1afb5d6151d418bad7cf3f6a763358`, features `voice`, `settings`, `screen`, `shell`, platform `web`). All 21 stages passed, including Web unit tests, production build, registered browser suites, and owned real-stack voice journeys at 1440 px and 393 px. The runner retains its raw `REVIEW_REQUIRED` status and `visual_review: NOT_RUN`; this record documents the manual source-resolution review below without approving a screenshot baseline.

The focused Android Chrome touch scenario proves that PTT is offered without a keyboard binding, microphone state follows press/release, and pointer cancellation releases the microphone. A separate activation test covers first publication from the touch PTT listener session and retains the desktop requirement for a keyboard binding. Settings hide the key assignment on touch and explain how to hold the dock microphone.

## Visual review

Inspected the final generated captures at source resolution:

| Capture | Size | Observation |
| --- | ---: | --- |
| `android-touch-ptt-ready-390x900.png` | 390 × 900 | Dock mic is crossed out while idle; the action row remains aligned and fully visible. |
| `android-touch-ptt-held-390x900.png` | 390 × 900 | Held mic turns red and loses the slash, clearly marking the transmit interval. |
| `touch-ptt-settings-390x844.png` | 390 × 1290 full-page | PTT mode shows hold guidance inside the activation card and no keyboard assignment button. |

The captures are retained locally under `.out/local-features/20261019-161809/images/` and are not staged as generated media. Their SHA-256 values are recorded here:

- Ready dock: `1e1876ba9092c548c0ad436b4d1b16d832b278c5b0575681236d8d3f0e98f01f`
- Held dock: `b047666fb8b515e3719cd34ba1373f1794995866e26a347f3dd8110c646f9662`
- PTT settings: `22cb8a7304a520345a6edc5ec6ea91187c1bb54638d94426a2c749dd2e6fd768`

The real-stack stages confirm voice-session continuity at desktop and mobile browser widths. The microphone permission/publish gesture itself is covered by unit and browser-fixture tests, not by a physical Android microphone; physical Android, native clients, and audio QoE remain NOT_RUN.
