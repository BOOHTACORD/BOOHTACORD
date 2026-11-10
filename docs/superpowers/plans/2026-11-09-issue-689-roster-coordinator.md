# Issue 689 process-scoped voice roster coordinator

**Goal:** Share bounded refresh work per account and publish ordered authoritative roster states without per-socket polling.

**Route:** `backend/internal/voice/coordinate_roster`; input is the existing `list_connected_participants.Service` and verified notifier. This packet does not grant or check session access at delivery.

- [x] Test initial subscription barrier, per-account isolation, coalescing, no-change suppression, unavailable/recovery and bounded workers.
- [x] Confirm RED; implement one reconciliation loop, bounded worker queue, replaceable one-slot snapshots and stale-result rejection.
- [x] Run focused tests/race and spec traceability. Runtime wiring, per-recipient current ACL/session checks, frame limits and load remain separate gates.
