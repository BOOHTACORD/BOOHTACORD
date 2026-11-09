# Issue 689 Maintenance Observer Implementation Plan

> **For agentic workers:** Execute this leaf inline, preserving the existing SSE behavior until compatible clients and transports are ready.

**Goal:** Observe authoritative maintenance state once per process and provide ordered, bounded state updates to subscribers.

**Architecture:** A single worker reads outside its lock, with a bounded context and periodic reconciliation while subscribers exist. Each subscriber registers before its initial read; a subscriber arriving during an in-flight read waits for the next read. Each subscriber has a one-element replaceable queue; unknown state remains distinct from inactive.

**Tech Stack:** Go, PostgreSQL-backed existing maintenance reader, Go testing.

---

### Task: Shared observer leaf

**Files:**
- Create: `backend/internal/maintenance/observe_state/observer_test.go`
- Create: `backend/internal/maintenance/observe_state/observer.go`
- Create: `backend/internal/maintenance/observe_state/subscription.go`
- Create: `backend/internal/maintenance/observe_state/barrier_test.go`
- Create: `backend/internal/maintenance/observe_state/coalescing_test.go`
- Create: `backend/internal/maintenance/observe_state/integration_database_test.go`
- Modify: `backlog/tasks.yaml`

- [x] Write tests for initial and changed state, unavailable and recovery, no subscribers, late subscription during an in-flight read, bounded latest-state delivery, burst coalescing, timeout and shutdown.
- [x] Run `go test ./internal/maintenance/observe_state -count=1` from `backend` and confirm RED. Also observe RED for burst coalescing, timeout and shutdown before fixing them.
- [x] Implement the worker and subscription boundary. Assign a fresh generation at startup; increment revision only on state or availability change; never perform a read under the subscriber lock.
- [x] Run the focused tests and race detector; run the spec traceability check for the backlog change.
- [x] Replace the five-second late-subscription delay with a shared fresh read; coalesce bursts with a short 50 ms minimum spacing.
- [ ] Integrate with the transport and lifecycle, measure query rate and initial latency under reconnect load, and repeat security and real-stack acceptance. This leaf is not live yet.
