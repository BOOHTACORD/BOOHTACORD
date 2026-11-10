# Issue 689 public connection admission

**Goal:** Bound unauthenticated WebSocket connections globally and per source while allowing at least twenty clients behind one NAT.

**Route:** `backend/internal/realtime/admit_public_connection`, using the trusted source selected by `security/rate_limit` at the handler boundary.

- [x] Test invalid configuration, canonical IP grouping, NAT capacity, global capacity, idempotent release, and concurrent admission.
- [x] Confirm the tests fail before implementing the quota.
- [x] Implement bounded counters with no network work or logging inside the lock.
- [x] Run package tests, race detector, and spec traceability; record evidence. Integration with a handler is a separate packet.
