# Issue 689 Public Realtime Source Resolution Plan

> **For agentic workers:** Execute this small leaf inline before wiring public WebSocket admission.

**Goal:** Let public connection quotas use exactly the same trusted-proxy source as the existing handshake rate limiter.

**Architecture:** Expose the existing bounded forwarded-chain resolver through its configured limiter; do not duplicate proxy parsing or log source identities.

**Tech Stack:** Go, existing rate limiter, Go testing.

---

### Task: Reuse the configured trusted-source policy

**Files:** `backend/internal/security/rate_limit/source.go`, `backend/internal/security/rate_limit/source_test.go`, `backlog/tasks.yaml`.

- [x] Test a trusted proxy chain and an untrusted peer with a forged forwarded address through the public accessor.
- [x] Run `go test ./internal/security/rate_limit -run TestLimiterExposesSameTrustedSource -count=1` and confirm RED.
- [x] Add an accessor delegating to the existing `sourceKey` implementation and leave middleware behavior unchanged.
- [x] Run the full package tests, WSL race detector and spec traceability verifier. Guest admission remains a separate packet.
