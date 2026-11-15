# Issue #787 PR2 — adaptive Web stream switcher

**Scope:** Web stream-switcher popup/grid only. Flutter UI, telemetry contracts, paired media quality and release/load gates are outside this PR.

## Results

- Focused browser scenarios: **PASS**. The full registered `screen_share_ui` Playwright suite passed 53/53 tests, including single-unselected, two-stream, eight-stream desktop/mobile, preview loading/failure, keyboard selection/focus restoration and publication removal/fallback cases.
- Web unit/reference tests: **PASS**, 24/24. TypeScript and production build: **PASS** with `VITE_PUBLIC_ORIGIN=https://v.bootybay.ru`; the build emits the existing LiveKit dynamic-import and large-chunk warnings.
- Local feature run `.out/local-features/20261116-000124/`: **FAIL as a complete gate**. All Web suites passed except `web-screen_profile`, which is **BLOCKED** by one skipped minimal publisher/viewer test. Web-to-SFU lifecycle checks at 1440 and 393 px passed. Flutter component captures passed; the Flutter unit suite is **BLOCKED** by one skipped test; iOS runtime is **BLOCKED**. The unrelated Android `issue786_deafen_test` failed while waiting for the existing voice deafen roster state (`issue689_support.dart:78`, called by `issue786_deafen_test.dart:82`). This PR changes no Flutter files. The report records the exact stage results.
- Android general workspace smoke and the registered Android `issue689` targets passed. They do not exercise the new Web switcher. No paired native stream-switcher, physical-media quality or capacity result is claimed.

## Visual review

Reviewed the browser captures at their source resolution:

- 1440 px, one unselected stream: one large 16:9 card fills the popup; its loading state is visible while `Эфир` remains distinct.
- 1440 px, two streams: equal-width cards use the cached image; `Эфир` and `Смотрим` have separate badges, and configured quality is prefixed with `Цель:`.
- 1440 px, eight streams: two columns scroll inside the panel without widening the page.
- 390 px, eight streams: one column stays within the viewport and scrolls inside the panel; the long caption clamps to two lines while the full accessible name and `title` remain available.

Browser artifacts are under `.out/issue348/browser/` and were copied into `.out/local-features/20261116-000124/images/web-screen_share_ui/`. These fixtures validate UI states with synthetic cached-image responses; they do not establish a media-quality or capacity profile.
