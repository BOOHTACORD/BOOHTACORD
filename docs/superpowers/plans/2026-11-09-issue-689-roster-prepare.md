# Issue 689 bounded roster delivery preparation

**Goal:** Reauthorize private snapshots off the WebSocket writer with bounded concurrency, discard stale observations, and preserve critical session failure.

**Route:** `backend/internal/voice/prepare_roster_delivery`, consuming coordinator subscriptions and the per-recipient guard.

- [x] Test valid, stale, unavailable and revoked results, cancellation, bounded concurrent checks and slow recipient replacement.
- [x] Confirm RED; implement a bounded asynchronous preparation path with no token/error-detail logging.
- [x] Run focused/race checks. Final writer, fresh-state fence immediately before write, true revocation race and real-stack/load acceptance remain separate.
