# Web to Flutter parity audit: 2026-10-14 to 2026-10-24

Reviewed the first-parent history for changes under `clients/web` during the
previous ten days: 62 merge/commit entries through 2026-10-24. Compared the
user-visible feature families with Flutter source, tests, and recent parity
work before opening new implementation tasks.

| Web change family | Flutter status after audit |
| --- | --- |
| Workspace navigation, member profiles, message history/actions, search, pinned mini-player, and settings work from #356–#370 | Already covered by the Flutter workspace parity delivery in #508 and its focused `web_parity` tests. |
| Screen-share audience, full-screen handoff, stage controls, and viewer presence from #448 and #497–#553 | Already implemented across #497, #508, #565, and #566; Flutter has dedicated audience, fullscreen, transient-control, and responsive-geometry tests. |
| Touch voice controls, participant voice/screen indicators, and support contact/consent | Flutter already has touch PTT and screen controls; voice/screen status and support consent are covered by #565 and #517. #522's GitHub bridge is server-side and uses the shared support conversation contract. |
| Password-reset visibility and session/authentication recovery | Password reset UI and secure Flutter session restoration already exist; the recent token-preflight and login-capacity changes are shared API/server behavior. Browser cookie retention remains Web-specific storage behavior. |
| Web scrollbar, browser sidebar gutter, and update-banner/profile CSS adjustments | These changes target browser CSS and browser update surfaces. They do not add a shared user action or backend contract requiring a Flutter feature. |
| Independent chat, voice, and roster connection-status card from #505 | Missing in Flutter. Implemented as the next parity leaf (FV2-059); details and evidence are in `flutter-connection-status-2026-10-24.md`. |
| Channel favorites | Web already supported this; Flutter was missing the navigation shortcut. Ported in #567 and merged into `master` as `6ccc4b58`. |

Infrastructure-only CI/runner changes, server hardening, telemetry storage, and
Web-specific test-harness changes were excluded from client UI parity unless
they introduced a client-visible contract. No further functional gap was
confirmed in the reviewed feature families; browser-specific CSS is not treated
as a pixel-identical Flutter requirement. Device-level acceptance is tracked
separately and is not inferred from widget tests.
