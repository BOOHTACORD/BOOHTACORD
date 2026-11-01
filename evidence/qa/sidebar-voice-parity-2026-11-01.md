# Sidebar and voice parity acceptance — 2026-11-01

Run: `.out/local-features/20261101-182026/`

Base: `origin/master` (`e42dc22b96e0824c271c4462d53ec4683f98773d`)

Features: `auth`, `connection_status`, `screen`, `shell`, `support`, `voice`

## Results

- Web unit, build, accessibility and selected browser suites: **PASS**.
- Web real-stack at 1440px and 393px: **PASS**. The owned Egress container used
  `linux/amd64` because the local ARM64 image cannot resolve its configured user.
- Flutter full unit/widget suite: **PASS**.
- Flutter component captures: **PASS**.
- Android runtime: **PASS**.
- iOS runtime: **BLOCKED**. No iOS Simulator devices are available on this host;
  `xcrun simctl list devices available` returned an empty device list.

## Visual review

Inspected source-resolution captures `images/flutter-captures/flutter-sidebar-channel-scroll-300x640.png`
and `images/flutter-captures/parity-voice-1024x480-scale2.png`.

At 300×640, the guild header, search/tabs and user footer stay fixed while the
channel rows move within the sidebar list. At 1024×480 with 200% text, the
sidebar no longer reports a flex overflow; its status card remains inside the
scrollable navigation region because the fixed header, connected dock and
footer leave limited list height. Native iOS visual/runtime acceptance remains
unverified.

Overall local acceptance remains **BLOCKED** until the applicable iOS runtime
can be exercised. Generated captures and logs are retained under `.out/` and
are not tracked.

## Follow-up: explicit voice exit and CI capture inventory

Run: `.out/local-features/20261101-192008/`

- Web unit/build/accessibility, selected browser suites, and real-stack at
  1440px and 393px: **PASS**.
- Flutter full unit/widget suite and component captures: **PASS**.
- Android runtime: **PASS**.
- iOS runtime: **BLOCKED**, still no Simulator device on this host.
- Reviewed `images/flutter-captures/flutter-sidebar-after-voice-leave-300x640.png`
  at 300×640. With a stale voice-error phase after explicit exit, the status
  card is absent; the fixed guild header/search/tabs and profile footer remain
  while navigation rows occupy the scroll area.
- Registered both new Flutter sidebar captures in the mandatory CI visual
  inventory. The missing inventory entry caused PR #640's Flutter artifact
  publication job to fail after its Dart profile had passed.

Local acceptance remains **BLOCKED** only for the unavailable iOS Simulator;
Android and Web acceptance and the Flutter UI/widget evidence pass. The
captured screenshots and full report remain in `.out/` and are not tracked.
