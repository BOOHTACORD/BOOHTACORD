# Issue 689 Web authenticated maintenance state

**Goal:** Apply maintenance events in the existing authenticated WebSocket without triggering unrelated protected REST refreshes.

**Route:** `clients/web/src/maintenance` owner and exact workspace dispatch edge; guest/auth application handoff follows separately.

- [x] Test per-attempt ownership, invalid initial event and unrelated event routing.
- [x] Confirm RED; connect lifecycle callbacks, opt into the server capability and route maintenance to the feature state.
- [x] Run focused and existing Web tests, TypeScript build and registry checks; record real-browser acceptance as pending.
