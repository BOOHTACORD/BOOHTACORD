# Web stream viewing across text navigation — #349 — 2026-10-19

**Scope:** Web viewer continuity when navigating from an active voice channel to
TEXT/DM/settings, with stream pinning removed. This is local candidate evidence
for the changes on `codex/web-stream-channel-switch`; the implementation is
based on master `59c15c65c6751173fc5e668be383e88a62276a58`.
Initial candidate revision: `05e2b929ec821245334ce2f4402ab0aa518b9358`.
Post-master tested revision: `abc5d429` (includes master `b1c9f2c7`).

## Results

- Focused mini-player browser suite: **PASS**, 20/20 Chromium scenarios, rerun after synchronizing with master.
- Post-master focused Web tests: **PASS**, 26 Vitest tests; production `vue-tsc` and Vite build: **PASS**.
- Local-feature harness at initial candidate revision `12b541f9`: **PASS** for Web unit tests, production
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

## Retest — 2026-10-20

This retest supersedes the earlier blocked API/SFU result above. It was run on
PR head `12b7f60f57abaed9b5b50ea71e65bd888544d905` plus the pending QA fixes,
against PR base `a946915037619d9d46a229c2ed60ba51a70a1ba7`.

- Focused lifecycle and feature-policy tests: **PASS**, 9 tests.
- Registered local Web feature check for auth/chat/screen/shell/voice: **29/29
  stages PASS**, including Web unit tests, build, all registered browser suites,
  and real API/PostgreSQL/LiveKit lifecycle at 1440px and 393px.
- The real-stack screen scenario published a synthetic canvas and quiet
  oscillator, decoded the stream in both clients, retained the same media
  elements/tracks/peer connections while navigating TEXT and DM, and passed
  pause, mute, expand, stop, logout cleanup and reconnect checks.
- No hardware capture or media-quality claim is made. Native runtime was not
  run because this change and acceptance scenario are Web-only.
- Targeted visual review: **PASS** at source resolution for the eight
  issue349-related captures listed below. The mini-player stays above TEXT/DM
  content at desktop and phone widths; the composer and voice dock remain
  reachable; the tested 320px and 390px/200% layouts wrap or truncate long
  labels without clipping the mini-player controls or causing horizontal page
  overflow. No pin control appears.
- The generated feature report remains **REVIEW_REQUIRED** because its broad
  multi-feature run contains 1,091 screenshots and only the issue349-related
  subset was visually reviewed. Report:
  `.out/local-features/20261020-112958/index.html`.

## Retest captures inspected at source resolution

- `.out/local-features/20261020-112958/images/web-real-stack/1440/mini-player-text.png`
- `.out/local-features/20261020-112958/images/web-real-stack/1440/mini-player-dm.png`
- `.out/local-features/20261020-112958/images/web-real-stack/393/mini-player-text.png`
- `.out/local-features/20261020-112958/images/web-real-stack/393/mini-player-dm.png`
- `.out/local-features/20261020-112958/images/web-mini_player/mini.browser-390px-at-200--20efd-ically-retained-mini-player/dm-draft-390-text-200.png`
- `.out/local-features/20261020-112958/images/web-mini_player/mini.browser-chat-zoning-320-text-200/dm.png`
- `.out/local-features/20261020-112958/images/web-mini_player/mini.browser-short-viewpor-4cdbf-ntity-after-text-navigation/short-paused.png`
- `.out/local-features/20261020-112958/images/web-mini_player/mini.browser-mobile-screen-73f7c-the-DM-composer-send-button/mobile-screen-share-notice-dm.png`
