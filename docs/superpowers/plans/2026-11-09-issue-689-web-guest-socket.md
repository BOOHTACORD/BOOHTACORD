# Issue 689 Web guest maintenance socket

**Goal:** Manage one retrying, bounded public maintenance WebSocket that rejects non-public frames and stale callbacks.

**Route:** `clients/web/src/maintenance`, consuming the generation-safe feature state.

- [x] Test open, initial snapshot, timeout, retry, malformed/private frames, and stop without late reconnect.
- [x] Confirm RED and implement public-only transport with existing bounded retry policy.
- [x] Run focused checks and register feature acceptance; application handoff and real browser acceptance remain separate.
