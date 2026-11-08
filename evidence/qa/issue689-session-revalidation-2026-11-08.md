# Issue 689: session revalidation packet

Status: **PASS_SCOPED** for the interval and the existing connection package tests; issue 689 remains incomplete and release acceptance is **NOT_RUN**.

- Source: `master` base `10e0e44f28a2612d2f7fecf5be06931cf91fb166`, plus the packet changes in `backend/internal/realtime/connect_session` and matching documentation.
- RED: `go test ./internal/realtime/connect_session -run TestRevalidationInterval -count=1` failed to compile because the new interval function did not exist.
- GREEN: the same focused command passed on Windows Go 1.26.4. It covers zero, negative, over-limit, exactly ten seconds and shorter intervals.
- Integration: `go test ./internal/realtime/connect_session -count=1 -v` passed with no skips using the local QA PostgreSQL 17.6 and the repository's unique-schema fixture, including own-session revoke and account-block socket closure. The DSN remained in the process environment and is not recorded here.
- Race: `CGO_ENABLED=1 go test -race ./internal/realtime/connect_session -count=1` passed under WSL Ubuntu, Go 1.26.8; database integration tests were skipped in this run. `go vet ./internal/realtime/connect_session` passed on Windows.
- `python -m unittest tools.verify.oncall_map.test_check` passed after the operator map and its source anchor were changed to ten seconds. The direct contract and spec traceability verifiers passed.
- Full `python -m tools.ci.native.contracts` on Windows: **FAIL**, 13 failures, 52 errors, 39 skips in its 1,333-test Python stage. Observed causes include Linux-only `fcntl`/`/usr/bin/tar`, missing Windows `openssl`, Unix permission assumptions, and the then-stale on-call interval anchor; later stages were not reached. The focused anchor tests passed after correction; the complete gate was not rerun.
- QA infrastructure: `python -X utf8 .out/local-qa/verify_deployment.py` passed 32 checks after startup. This deployment runs source `072426d60b1c0b1f7e5f66722a0da5faa00b50d7`, not the candidate, so its readiness is not candidate acceptance.
- The change bounds the periodic check interval. It does not implement or prove per-roster-write authorization, the shared observer, SSE removal, platform parity, capacity, cutover or rollback. No load or production test was run in this packet.
