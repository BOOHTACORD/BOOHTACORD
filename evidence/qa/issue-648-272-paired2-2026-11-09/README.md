# Android and Web recovery: paired repeat with live-client synchronization

Date: 2026-11-09. Product source `be97f71727a6d263390ebe13c30ad93228c71760`:
the isolated integration of PR #693 and PR #694. Android 15 emulator and
headless Chromium used separate synthetic accounts and an owned API,
PostgreSQL and LiveKit. No production service or account was used.

The previous integrated attempt reported fresh in-memory and API rosters but
its screenshot showed one participant, and its Web control failed. Its Web
script waited for Android's done marker before checking two participants,
while Android then waited only five seconds before teardown. This ordering
allowed a race with Android leaving. That is a test-harness explanation that
is consistent with the failure, not proof of the cause of every prior image.

This repeat corrected the test protocol: after a 130-second simultaneous
API/SFU outage, Android remained connected while the Web client checked its
own connected status and an authenticated API roster of at least two. Android
waited up to 90 seconds for the named peer to become visible and stayed alive
for another 20 seconds. Both driver and browser exited 0. Android showed
visible reconnect, a new lease in the original room, an automatically fresh
roster and the peer name. Chromium verified connected status and at least two
participants in the authenticated API roster before closing. All test
accounts and names are synthetic; no real media or conversation was saved.

The original-resolution Android screenshot (1080 x 2400) was inspected:
two distinct participants and the voice dock's two-participant count were
visible. Its SHA-256 is
`6922637195c13c89b58079bf3113a6b39f7b77f689365708bccd8c192b029dfa`.
The temporary Android, browser and ownership-control scripts are preserved
alongside this report. The owned services were stopped, temporary reverse
mappings removed, and the test package was absent after cleanup.

This establishes the stated emulator/Web scenario on the integrated source;
it does not establish physical-device or acoustic behavior, iOS/macOS,
production, load or the full canonical feature gate. Neither issue is closed
and no deployment or merge to master occurred.
