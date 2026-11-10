# Issue 689: roster subscription lifecycle adapter

**Route:** `backend/internal/app/voice_realtime`, one process-composition leaf.

- [x] Test that each socket gets an account-scoped coordinator subscription and asynchronous guard using its own session token; test cancellation and rejected admission.
- [x] Bridge the coordinator and bounded preparation pool to the socket interface with explicit ownership of cancellation and subscription cleanup.
- [x] Run focused tests and race detector. Live wiring, revocation/write ordering, real clients and load remain separate.
