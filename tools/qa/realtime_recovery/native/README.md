# Native R1 recovery acceptance

Runs the production Flutter AppState/UI, HTTP, WebSocket and LiveKit against a
disposable real Go/PostgreSQL/SFU stack. The observer and member are independent
logical sessions in one native process. Test storage namespaces isolate their
cookies; OS secure-storage, microphone quality and cross-device media are outside
this acceptance. Delays hold unchanged real HTTP results; no fake WS events.

Prerequisites: pinned Flutter SDK, local Linux Docker daemon, Windows build tools
for Windows; Android SDK/JDK and a dedicated API35 x86_64 AVD named
`BOOHTACORD_QA_R1_1121` for Android. Never use an existing personal app session.
Ports4910/4920/4980/4981/4982 must be free; controls bind to loopback and require
an ephemeral nonce. Cleanup is restricted to labelled resources owned by this run.
The Android runner refuses existing reverse mappings and removes only its own.

From the repository root:

```text
python -m tools.qa.realtime_recovery.native.run --platform windows --device windows --flutter <flutter.bat>
python -m tools.qa.realtime_recovery.native.run --platform android --device <owned-avd-serial> --flutter <flutter.bat> --adb <adb.exe>
python -m unittest tools.qa.realtime_recovery.native.test_endpoint tools.qa.realtime_recovery.native.test_prepare
```

Windows prepares the canonical hash-pinned updater SDK. Android permits pub get
to regenerate the untracked Java plugin registrant; suppressing it with no-pub
after removing that generated file breaks native WebRTC plugin registration.
Tracked or unknown files at that exact generated path are never removed.

The output is a fresh ignored `.out/` directory: source-bound `runtime.json`,
finite `scenario.json`, five actual native rendered PNGs and a private run log.
Inspect captures at original resolution; do not commit private logs/defines or
binaries. A zero exit and PASS require scenario assertions, owned cleanup and an
unchanged source fingerprint. Registration/build alone is not runtime acceptance.
