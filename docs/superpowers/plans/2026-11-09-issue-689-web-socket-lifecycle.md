# Issue 689 authenticated WebSocket lifecycle callbacks

**Goal:** Let snapshot domains invalidate their connection generation on every authenticated open, failure, retry and disconnect.

**Route:** `clients/web/src/realtime` connection owner, preserving existing delivery and reconnect behavior.

- [x] Test callback ordering for initial failure, retry, stale callbacks and explicit disconnect.
- [x] Confirm RED and implement optional callbacks scoped to each socket attempt.
- [x] Run focused tests and build; feature-state wiring and real browser acceptance follow separately.
