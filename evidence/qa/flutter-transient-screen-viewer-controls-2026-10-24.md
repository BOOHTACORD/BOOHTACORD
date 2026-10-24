# Web-to-Flutter parity review and transient viewer controls

Review window: the 10-day period ending 2026-10-24. Source: `master` at `e1f60ed67e777cc9dd7d03507a9ebb3a741f7a35`, including the merged Flutter member-presence change from PR #565.

## Web changes checked

- Screen viewer work from #514 and #538–#544: fullscreen, stop-watching, mini-player, audience and participant presentation, short-room layout, compact panels, and controls that hide while idle. Flutter already had the separate fullscreen route, stop-watching, persistent mini-player, audience/participant strip, and compact stage behavior. The remaining difference was that stage and fullscreen actions stayed visible at all times.
- Guild voice presence from #553 is already implemented in Flutter by #565, with voice-channel labels and a screen-sharing icon in the member panel.
- Voice, PTT, auth/session, support, telemetry, navigation, search, and message/DM changes were checked against Flutter features and tests. The relevant behavior is already present or was delivered in shared Web/Flutter changes during the review window.
- Flutter's native popup already dismisses on outside interaction. Scrollbar colors and CSS spacing are platform-specific visual details; no matching user-visible behavior gap was found.
- CI, backend, and evidence-only commits do not add Flutter client behavior.

## Implemented gap

`ScreenViewerActionLayer` now covers both the voice stage and fullscreen viewer. Desktop controls reveal on pointer activity and hide after 1.8 seconds, with a 200 ms fade and a 14 px downward slide. Keyboard focus keeps controls available. Android and iOS keep them visible because touch has no hover state. The translucent pointer listener preserves the fullscreen downward-swipe gesture.

## Verification

- `flutter test test/screen_viewer_transient_controls_test.dart test/screen_fullscreen_overlay_test.dart`: PASS.
- Full Flutter unit suite: PASS, 1,623 tests.
- Registered Flutter component captures: PASS, 260 tests.
- Web unit suite: PASS, 488 files / 1,625 tests.
- Web production build: PASS.
- Registered Web browser suites: PASS, including accessibility, auth/session retention, connection status, mini-player, password flows, screen profile/share UI, voice disconnect, and voice controls.
- Source-resolution visual review: `flutter-screen-viewer-transient-controls-1440x900.png` (1440 × 900). The fullscreen exit action is visible in the upper-right, stop-watching is centered at the bottom, and the publisher label remains clear at the top-left without overlap.
- Overall local feature report: `FAIL` due to environment prerequisites below; these remain blocked and are not treated as closed acceptance gates.
- Real API/SFU Web acceptance: `BLOCKED`. The local Docker installation has no Buildx/BuildKit support; the service image build reports `--mount option requires BuildKit`.
- Android and iOS runtime acceptance: `BLOCKED`. The local feature runner found no configured native devices (`devices={}`).

Report: `.out/local-features/20261024-142018/index.html`.
