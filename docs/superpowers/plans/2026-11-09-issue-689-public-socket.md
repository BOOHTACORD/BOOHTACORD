# Issue 689 public WebSocket transport

**Goal:** Provide a narrowly scoped public transport for maintenance state, without modifying active routes in this packet.

**Route:** `backend/internal/realtime/connect_public`; dependencies are the shared maintenance observer, trusted-source rate limiter, and anonymous connection quota.

- [x] Add WebSocket tests for ready and authoritative snapshot/change, database unavailability, origin/query rejection, rate limiting and quota.
- [x] Verify RED; implement admission before upgrade, bounded writes, close handling and exact public event payloads.
- [x] Run native tests and race detector; record evidence. Runtime registration, deployed-stack and client integration remain separate work.
