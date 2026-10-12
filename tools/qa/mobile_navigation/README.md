# #292 native mobile navigation runtime

This acceptance uses the production BoohtacordApp, its real secure-cookie API and an owned disposable PostgreSQL/Go/Caddy/LiveKit stack. ADMIN and MEMBER fixture sessions are separate. Two actual LiveKit listener rooms connect and their actual RTC candidate-pair/DTLS stats are read; no successful API replies, connection flags or rooms are mocked. This proves a retained RTC connection, not microphone capture, audible audio quality or a physical call.

Assigned ports: HTTPS4840, Tempo4842, Go4843, SFU HTTP4892/TCP4893/UDP4894 and Android OS-input bridge4844. Android reverses4840/4844/4893 only. The authenticated loopback bridge checks the assigned emulator/AVD before dispatching documented `adb shell input keyevent KEYCODE_BACK`; the actual app must observe the resulting Back and preserve the room, lease and conversation. It is emulator OS dispatch, not physical-device acceptance. iOS `handlePopRoute()` and integration pointer swipes are explicitly controlled app-route/drawer tests, not physical interactive route-Back proof.

Prepare an independent native package in `/private/tmp/boohtacord-qa292-flutter`. Copy `clients/flutter/` with package-root exclusions `/build/`, `/.dart_tool/`, `/ios/Pods/`, `/macos/Pods/` and `.symlinks`; retain executable source folders named `build`. Run `flutter pub get` in the copy. Coordinate the native build slot with other workers. Run from the repository root, one platform at a time:

```sh
python3 -m tools.qa.mobile_navigation.run_native --platform android --device emulator-5556
python3 -m tools.qa.mobile_navigation.run_native --platform ios --device <assigned-simulator-udid>
```

Android is restricted to `BOOHTACORD_QA_283_API35` on emulator5556. The current assigned iOS simulator is BOOHTACORD QA iPhone. Native output is ignored under `.out/qa292-20261012/{android,ios}`. The runner pins HEAD, dirty diff hash and full Flutter lib manifest before compilation and rejects a mismatched private copy. It archives old receipts and starts with RUNNING; failures cannot reuse a prior PASS. Temporary mode0600 inputs are removed, container ownership labels are checked before cleanup, and Android reverse ports are removed. Record executable hashes before deleting the private build package with disposable credentials.

Scenarios cover drawer selection, outside dismissal, Escape and Back/focus, controlled edge swipes for navigation and members, channel/DM headings, profile/audio/admin Back preserving DM draft, owned search query reopen and logout cleanup, all while an actual RTC listener room and lease remain unchanged. Any filter/tab reset observations are reported separately from the guaranteed owned-state criteria. Inspect every captured original-resolution image before visual approval. Captures contain synthetic aliases, empty conversations and navigation chrome; the unsent draft is not transmitted and is not captured.

Physical Android Back/iOS route gesture, VoiceOver/TalkBack spoken focus review and physical audio remain NOT_RUN. An observed runtime PASS cannot close #292 until its remaining acceptance criteria have their own evidence.

The API credential signer intentionally grants `canPublishData=false`. An initial QA data-packet expectation was invalid and was removed; server permissions and SDK behavior are unchanged. RTC proof reads native `Room.getPeerConnectionStats()` and records only bounded counts, never addresses, participant IDs or credentials.
