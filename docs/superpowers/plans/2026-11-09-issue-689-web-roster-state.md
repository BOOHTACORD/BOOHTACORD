# Issue 689: Web shared-socket roster state

**Route:** `clients/web/src/voice/roster_socket`, UI state only.

- [x] Test unknown, fresh, empty, unavailable, retained and expired states; reject stale revisions and reset safely on a new socket.
- [x] Implement state and manual retry through an injected existing-socket reconnect; do not create another connection or poll.
- [x] Run focused Web tests and build; workspace wiring, browser visual acceptance and native clients remain separate.
