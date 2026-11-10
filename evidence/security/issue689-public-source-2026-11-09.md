# Issue 689: public realtime source policy

Status: **PASS_SCOPED** for source resolution tests. No guest WebSocket route or production security acceptance is claimed.

The new accessor delegates to the existing configured trusted-proxy resolver. The new test failed before implementation, then the full `go test ./internal/security/rate_limit -count=1` passed on Windows and `go test -race` passed under WSL. Spec traceability passed. The test covers a trusted forwarded chain and ignores a forged header from an untrusted peer; NAT capacity, connection quotas and runtime proxy acceptance remain **NOT_RUN**.
