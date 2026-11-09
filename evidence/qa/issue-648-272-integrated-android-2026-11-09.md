# Integrated #648/#272 Android real-stack check: inconclusive paired result

Date: 2026-11-09. Product source was clean merge commit
`be97f71727a6d263390ebe13c30ad93228c71760`. Android 15 emulator and a
Chromium peer used separate synthetic accounts on an owned local API,
PostgreSQL and LiveKit. The temporary integration fixture SHA-256 was
`0bc5ff43e221979eeaba1f03ef256bff9e3df24d2a23102eb546d31822bc2f8d`.
The controller verified container ownership, stopped the API and SFU for
130 seconds and restarted both.

The Flutter driver exited 0: it observed interruption, visible recovery,
a new lease and return to the same room. Its in-memory roster reached fresh
with at least two participants and a subsequent API query also returned at
least two participants; the test printed `QA272_AUTO_FRESH` and passed.
However, source-resolution inspection of `roster-after-recovery.png`
(1080 x 2400, SHA-256 `0106f4e7c9a94a1f6a792608329f9622415068d13c8f871f9a143d7959a6d5fa`)
showed only one visible participant and a one-participant voice dock. The
separate browser control joined before the outage but its final check exited
1 with only a sanitized `windows-ready Error`; the harness does not identify
which final assertion failed. The state/API assertions alone therefore do
not prove both actual clients were visibly present after recovery. Timing,
peer reconnect and UI propagation require further investigation.

This is not a full canonical feature gate, physical device or acoustic test,
and does not justify closing either issue. The owned services were stopped,
temporary ADB reverses removed, test app package absent, and tracked generated
files restored. Production was not changed.
