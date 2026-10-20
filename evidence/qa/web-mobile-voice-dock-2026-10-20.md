# Web mobile voice controls acceptance — 2026-10-20

Scope: mobile Web connected voice room controls, Android-browser screen-capture feedback, and listener heading spacing. This is a Web UI check; the Android user agent in the browser scenario is simulated and does not establish native Android screen-capture behavior.

## Result

- PASS: Web unit suite, 1,593 tests across 478 files.
- PASS: Web production build with `VITE_PUBLIC_ORIGIN=https://v.bootybay.ru`.
- PASS: voice-interface Playwright suite, including Android Chrome user-agent and 393×900 mobile layout.
- PASS: full Web browser stages in `.out/local-features/20261020-153048/report.json`.
- PASS after the acceptance run: re-ran the full Web unit suite, voice-interface Playwright suite, and production build after the final warning-lifecycle cleanup.
- BLOCKED: API/SFU real-stack at 1440px and 393px. The dedicated `boohtacord-qa` Colima VM started, but Docker reported that its Buildx component is missing; `DOCKER_BUILDKIT=1` confirmed the same. The real two-client media path was not exercised.
- BLOCKED: Android and iOS runtime smoke in the cross-platform run `.out/local-features/20261020-151821/report.json`; Flutter unit and component captures passed, but no repository-recognized QA devices were available.

## Visual review

Inspected `.out/local-features/20261020-153048/web-voice_interface/controls.browser-Android-s-be72b-ping-the-mobile-dock-action/android-capture-unavailable.png` at its original 393×900 resolution. The room heading begins about 20px below the workspace header; participant cards remain centered; the duplicate controls beneath the roster are absent; the fixed bottom dock remains visible. The Android limitation message is absent before interaction and appears in full above the dock buttons after tapping screen share. No clipping or overlap remained in the reviewed state.

The real-stack/native statuses above remain BLOCKED and must not be treated as media or device acceptance.
