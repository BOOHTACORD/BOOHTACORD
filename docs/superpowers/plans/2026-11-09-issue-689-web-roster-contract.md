# Issue 689 Web voice roster contract

**Goal:** Strictly parse ephemeral voice roster snapshots and unavailable events without changing durable chat replay.

**Route:** `clients/web/src/realtime` typed parser and nearest tests; feature application and capability negotiation follow separately.

- [x] Test valid empty/populated rosters, strict fields/IDs/revisions and safe unavailable code.
- [x] Confirm RED; extend the typed parser without adding snapshots to durable cursor tracking.
- [x] Run focused Web tests and build; runtime, UI and load remain separate gates.
