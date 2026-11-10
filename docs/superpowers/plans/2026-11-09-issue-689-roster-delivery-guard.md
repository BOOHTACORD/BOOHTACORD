# Issue 689 per-recipient roster delivery guard

**Goal:** Recheck the current session, visible channels and exact participant leases immediately before an authorized snapshot can be written.

**Route:** `backend/internal/voice/authorize_roster_delivery`, consuming the existing repository and internal lease proof.

- [x] Test revoked or changed sessions, missing/changed channel and lease, renamed participant, database failure and valid empty snapshots.
- [x] Confirm RED; implement fail-closed checks with bounded caller context and safe error classes.
- [x] Run native/race tests and a PostgreSQL fixture. This guard is not yet wired into the socket writer.
