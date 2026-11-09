# Issue 689 deterministic roster snapshots

**Goal:** Prepare full authorized roster results for stable comparison and bounded delivery without silently dropping rooms or participants.

**Route:** `backend/internal/voice/normalize_roster`; input remains the existing double-checked PostgreSQL/LiveKit service result.

- [x] Test deterministic sorting, empty arrays, input immutability, malformed/duplicate data and oversize rejection.
- [x] Confirm RED; normalize and encode without changing the underlying source-of-truth service.
- [x] Run package tests, race detector and spec traceability; coordinator, outbound ACL and actual frame limit remain separate.
