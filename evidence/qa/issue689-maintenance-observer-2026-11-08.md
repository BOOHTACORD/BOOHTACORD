# Issue 689: maintenance observer development evidence

Status: **IN_PROGRESS**. This package is not registered in the runtime and does not replace the existing stream.

The observer maintains bounded one-state subscriber queues, checks the read deadline, distinguishes unavailable from inactive, shares reads, and orders a subscription after any in-flight read. The first version made a late subscriber wait for the next periodic interval. A follow-up now requests a fresh shared read with a 50 ms minimum spacing to coalesce bursts. Query rate, latency and correctness under real reconnect load remain unmeasured; this is not yet transport acceptance.

- RED observed for missing implementation, connection burst producing 21 reads, treating an expired read as successful, and shutdown leaving a subscription open.
- `go test ./internal/maintenance/observe_state -count=10` passed for the unit tests after coalescing was added; `go test -race ./internal/maintenance/observe_state -count=3` passed in WSL before the database test was added.
- `go test ./internal/maintenance/observe_state -count=1 -v` passed without skips against a unique schema in the local PostgreSQL 17.6. The existing maintenance service changed the row and the observer detected it; this does not exercise the actual operator CLI.
- `tools/verify/spec_traceability/verify-spec-traceability.ps1` passed after adding the leaf backlog entry.
- Browser, Android emulator, Windows, macOS, iOS, production-like candidate, failure injection and load: **NOT_RUN** for this component. The observer is not connected to a WebSocket route or the later event contract.

Follow-up: the late-subscription test failed with the original interval and passed after the change. Twenty repeated unit runs, three WSL race runs and one real PostgreSQL run without skips passed. The PostgreSQL run still exercises the service rather than the actual operator CLI.
