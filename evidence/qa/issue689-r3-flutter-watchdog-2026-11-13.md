# Issue #689 R3: Flutter silent socket, partial evidence

- Shared Flutter requests the heartbeat protocol for authenticated and guest
  sockets. A valid heartbeat is consumed outside feature delivery and cursor
  tracking; missing heartbeats for 45 seconds close the owned socket. On resume,
  elapsed silence is checked even when the platform suspended timers.
- Focused widget tests cover authenticated and guest recovery, malformed
  heartbeat rejection, unknown events and resume. The 62-test realtime and
  maintenance regression suite passed with the final watchdog implementation.
  A real Dart loopback socket test negotiated heartbeat and reconnected after
  its peer went silent.
- An Android API 35 x86_64 emulator (`emulator-5560`) ran the native integration
  test against a loopback peer: the socket was replaced after 46 seconds, PASS.
  The test APK SHA-256 was
  `d16e1d655f1275df326151cbedfe5efecb41dc41467c3afda35f40e44fb46510`.
  This test ran from the working tree subsequently committed as `1cf328161`;
  it is not a release build.
- The existing real guest loopback test also passed against a server that does
  not select a subprotocol. Such a legacy connection has no heartbeat watchdog.
- Android full real-stack/visual acceptance for this change, actual network
  switching, background suspension on a device, iOS, physical devices, production
  and rollback are NOT_RUN. This test proves no media or capacity claim.
