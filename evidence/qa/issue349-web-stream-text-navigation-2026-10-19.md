# Web stream viewing across text navigation — #349 — 2026-10-19

**Scope:** Web viewer continuity when navigating from an active voice channel to
TEXT/DM/settings, with stream pinning removed. This is local candidate evidence
for the changes on `codex/web-stream-channel-switch`; the implementation is
based on master `59c15c65c6751173fc5e668be383e88a62276a58`.
Candidate source revision: `05e2b929ec821245334ce2f4402ab0aa518b9358`.

## Results

- Focused mini-player browser suite: **PASS**, 20/20 Chromium scenarios.
- Selected local-feature harness checks: **PASS** for Web unit tests, production
  Web build, accessibility checks, browser suites for screen/voice/chat/shell/auth,
  Flutter unit tests and Flutter component captures.
- Visual review: **PASS** for the five generated browser captures listed below.
  At 320px and 390px, the stream remains docked above the conversation and the
  pause, audio, expand and close controls remain visible. No pin control appears.
  Text composition stays within the viewport. At 200% text, long labels wrap or
  truncate while the browser geometry reports no document overflow. Desktop
  keeps the dock aligned with the conversation, and touch controls remain usable.
- Actual API/SFU two-client acceptance: **BLOCKED / NOT_RUN**. The local-feature
  harness could not build the API because this host's Docker lacks Buildx:
  `docker: unknown command: docker buildx`; the Dockerfile also reported that
  `--mount` requires BuildKit. Both 1440px and 393px real-stack runs stopped at
  this setup step, before an actual publisher/viewer session.
- Android and iOS runtime acceptance: **BLOCKED / NOT_RUN**. This request is for
  Web; the harness did not provide these native runtime targets.

## Browser captures inspected

Screenshots are generated into ignored local `.out` artifacts and are not
committed. They were inspected at source resolution:

- `.out/local-features/20261019-230825/web-mini_player/mini.browser-chat-zoning-320-text-100/text.png`
- `.out/local-features/20261019-230825/web-mini_player/mini.browser-chat-zoning-320-text-200/text.png`
- `.out/local-features/20261019-230825/web-mini_player/mini.browser-chat-zoning-1440-text-100/text.png`
- `.out/local-features/20261019-230825/web-mini_player/mini.browser-390px-at-200--20efd-ically-retained-mini-player/dm-draft-390-text-200.png`
- `.out/local-features/20261019-230825/web-mini_player/zoom.browser-touch-control-c663c-a-resized-keyboard-viewport/touch-short.png`

## Limitations

The harness overall is **FAIL** because actual API/SFU setup was blocked by the
host's Docker installation. Browser fixtures, unit tests and builds do not prove
live media subscription continuity. Keep the real-stack gate open and rerun the
two-client acceptance on a host with Docker Buildx. No native, hardware capture,
or media-quality claim is made.
