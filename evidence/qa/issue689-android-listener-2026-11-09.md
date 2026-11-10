# Issue 689: Android listener during application reconnect

- PASS: `python3 -m tools.qa.local_features.native --platform android --device
  emulator-5554 --target integration_test/issue689_listener_test.dart` used the
  dedicated AVD and disposable local Go/PostgreSQL/LiveKit stack. The native
  receipt says `mocks: false`, `physical_device: false` and `media: NOT_RUN`.
- A synthetic account joined the actual SFU as a listener. Its current roster
  contained its account. Closing the application WebSocket led to a fresh socket
  and roster while the same room object and listener state persisted. Leave and
  logout completed; no legacy stream or roster polling call was observed.
- Source: HEAD `72928320d` with uncommitted changes, not an immutable release.
  This scenario tests listener connection and lifecycle, not transmitted audio,
  microphone capture, quality, physical devices or multi-user capacity.
- The 1080×1920 capture was reviewed at source resolution. Connected voice,
  one roster participant, muted microphone indicator and navigation are visible.
  SHA-256: `84f5f94710eb776a163fc15b0456a4791f4faf635678166738c8a329ea4e9e72`.
- PASS: the listener scenario was repeated after the session/resource locking
  changes using `.out/issue689-android-listener-locked/`; the real-stack native
  receipt again reports no mocks and no physical/media-quality acceptance. Its
  1080×1920 capture was inspected and shows the connected listener and roster;
  SHA-256 `2a131df075dc465519432ab28f6a002b36e62192675e3259e47d03460db109df`.
