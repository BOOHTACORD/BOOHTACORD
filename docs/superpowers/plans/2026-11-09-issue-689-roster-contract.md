# Issue 689 typed voice roster events

**Goal:** Define strict versioned authorized roster snapshot and safe unavailable events without inventing a product channel-count limit.

**Route:** `contracts/realtime.schema.json` and nearest schema validator tests; runtime and clients are separate packets.

- [x] Test populated/empty snapshots and reject malformed IDs, revisions, timestamps, extra fields and unsafe failure details.
- [x] Confirm RED and add exact schemas using existing voice participant fields and fixed error code.
- [x] Run schema and native contract checks; payload-size enforcement and runtime acceptance remain separate.
