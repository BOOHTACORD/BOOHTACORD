# Issue 689 public realtime lifecycle

**Goal:** Own one maintenance observer and the independent public admission budget for the process; make its shutdown bounded.

**Route:** `backend/internal/app/public_realtime`, called by application composition in the following route packet.

- [x] Test startup, initial authoritative state and cancellation of active sockets; reject invalid origins without starting workers.
- [x] Confirm RED, implement process-owned observer and separate bounded budgets.
- [x] Run Go tests and race detector, record evidence. Registration, metrics and load tuning remain separate.
