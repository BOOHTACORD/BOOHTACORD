# Issue 689 authenticated maintenance delivery

**Goal:** Deliver maintenance on the existing authenticated socket to clients explicitly negotiating the new capability; preserve legacy clients while migrating.

**Route:** `backend/internal/realtime/connect_session`, using one process-owned observer. Runtime wiring is a subsequent packet.

- [x] Test legacy clients receive no new event, negotiated clients receive snapshot/change, and unknown state closes safely.
- [x] Confirm RED; subscribe before ready, use the existing single writer and keep maintenance outside durable replay.
- [x] Run focused and legacy regression tests plus race detector; record remaining integration and client work.
