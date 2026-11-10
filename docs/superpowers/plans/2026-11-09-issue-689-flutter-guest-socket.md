# Issue 689: Flutter public maintenance socket

**Route:** `features/session/maintenance_socket`, guest transport.

- [x] Test strict public event order, timeout/retry, late-open cleanup and cancellation with owned fake sockets.
- [x] Add a bounded guest WebSocket owner with no cookie or client commands, using the existing typed maintenance state.
- [x] Run focused tests, analyzer and real loopback socket check. Application handoff, native UI, AVD and load remain separate.
