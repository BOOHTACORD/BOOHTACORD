# Issue 648: forced-transfer recovery race, fixed candidate

2026-11-09; integrated source `be97f71727a6d263390ebe13c30ad93228c71760`
plus the two-line `lease_events/revocation.dart` change to clear the selected
channel when an accepted server revocation ends active recovery and no room or
admission is pending. The previously failing focused unit test reproduced the
stale channel after a synthetic release 503; after the change that test and
13 adjacent voice recovery/disconnect tests passed, and focused Dart analysis
passed. The failed real-stack test is in adjacent
`issue-648-forced-race-fail-2026-11-09` evidence.

The corrected Android 15 emulator and Chromium repeat used a local owned
API/PostgreSQL/LiveKit, two sessions of one synthetic account and the same
explicit Caddy 503 injection for DELETE voice leases. Chromium's successful
lease request was observed as `transfer=true`; its credential request was
held until the restarted SFU port listened. Android cancelled recovery, cleared
its selected voice channel and remained out for 90 one-second observations.
Chromium connected and stayed connected in nine ten-second checks. Android,
browser and control processes exited 0. The inspected original 1080 x 2400
Android screenshot showed voice disconnected; SHA-256
`a11afdb68505fd776c34426961448e6d8345be1e834d9a5038cf8206895e22e8`.

The canonical `tools/qa/local_features/check.sh --feature voice --platform
android --base 8306413a84c224a712509d7a059916c95b00bd3c --real-stack
--native-device android:emulator-5556` attempt exited 1 before tests: the
Windows `python3` app-execution alias could not find Python. The emulator AVD
name also does not satisfy the canonical dedicated QA naming requirement.
This manual real-stack result does not turn the canonical gate into PASS.
The owned stack stopped, temporary emulator reverses were removed and the test
package was absent. Physical devices, acoustic behavior, iOS, production,
full issue acceptance and deployment are not claimed.
