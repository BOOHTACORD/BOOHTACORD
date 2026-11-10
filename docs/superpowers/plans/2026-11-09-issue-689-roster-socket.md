# Issue 689: guarded roster socket delivery

**Route:** `backend/internal/realtime/connect_session`, one bounded delivery packet.

- [x] Add tests for negotiated delivery, stale-state suppression, fixed unavailable behavior and session revocation; retain legacy behavior without capability.
- [x] Connect a narrow prepared-delivery interface to the existing single socket writer; limit complete encoded frame size without truncation.
- [x] Run focused and race checks. Application composition, simultaneous revocation/write proof, full client migration and load remain separate packets.
