# Issue 689 roster snapshot freshness fence

**Goal:** Allow delivery code to reject a prepared roster if its account scope was invalidated or its subscription closed before writing.

**Route:** `backend/internal/voice/coordinate_roster` subscription and state lifetime; no network work occurs under the coordinator lock.

- [x] Test invalidation, fresh state, changed subscriptions and close against a queued snapshot.
- [x] Confirm RED; attach an internal observation stamp and expose a narrow current-state check.
- [x] Run focused and race tests; guard-to-writer integration and final revocation races remain separate.
