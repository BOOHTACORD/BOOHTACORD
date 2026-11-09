# Issue 648: second-device voice join while Android is recovering

2026-11-09; integrated candidate `be97f71727a6d263390ebe13c30ad93228c71760`.
Android 15 emulator and Chromium used separate sessions of the same synthetic
account against an isolated API/PostgreSQL/LiveKit. The owner-checked
controller stopped SFU after Android joined. While Android reported active
recovery, the browser used the actual Web UI to join the room; the API accepted
a new browser voice lease. The controller started SFU and waited for TCP 4981;
the test held the browser's credential request until that port was listening,
then allowed the real request to continue. This is a test synchronization
boundary, not an unmodified end-to-end network path.

The browser subsequently showed connected and remained connected in nine
checks spaced ten seconds apart. Android reported recovery cancelled and no
selected voice channel for 90 one-second observations. The browser, Android
driver and owner-checked controller exited 0. The 1080 x 2400 Android
screenshot (SHA-256
`9ea925f7bc25d8ae507a328f2922996089566ec57a1a59ae2bd96b6fca0bbcf6`)
was inspected: it showed voice disconnected while the synthetic account was
listed in the room. This verifies the scoped second-device race under these
conditions. The browser lease request's `transfer` value and whether the
previous lease was still active at acquisition were not captured; do not use
this to claim that the specific forced-transfer branch was exercised.

The first attempt obtained a browser lease but failed to connect before the
restarting SFU was ready; the Android cancellation assertion then failed.
That attempt did not establish an active second device. The repeat above adds
explicit port readiness before releasing the credential request. Scripts for
the repeat are included here. Owned services, temporary reverses and test app
were cleaned up. Physical media, production, full acceptance and deployment
remain out of scope.
