# Issue 689 Session Revalidation Implementation Plan

> **For agentic workers:** Execute this focused packet inline. Later transport and client packets require their own source-based plans and acceptance.

**Goal:** Bound authenticated WebSocket session revalidation to at most ten seconds while preserving shorter configured intervals.

**Architecture:** Normalize the interval at the connection handler boundary, before starting its existing ticker. This does not alter event delivery or claim roster authorization is implemented.

**Tech Stack:** Go, coder/websocket, Go testing.

---

### Task 1: Bound the session check interval

**Files:**
- Create: `backend/internal/realtime/connect_session/revalidation_interval_test.go`
- Modify: `backend/internal/realtime/connect_session/connection_contract.go`
- Modify: `backend/internal/realtime/connect_session/http_handler.go`
- Modify: `docs/architecture/api-and-realtime.md`

- [x] Add table-driven tests for default, negative, excessive, exactly ten seconds, and shorter intervals.
- [x] Run `go test ./internal/realtime/connect_session -run TestRevalidationInterval -count=1` from `backend`; confirm it fails before implementation.
- [x] Normalize nonpositive or excessive intervals to ten seconds; retain positive shorter intervals. Use the normalized value in the handler and update the existing architecture description.
- [x] Repeat the focused test, then run the package tests against the local disposable-schema PostgreSQL fixture; also run the race detector in WSL without a database.
