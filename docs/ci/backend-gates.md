# Backend gate (#389)

`ci-backend.yaml` now runs three independent hosted jobs. Their filesystems,
processes, Docker daemons and published ports are on separate runner machines:

| Job | Complete required coverage | State isolation |
| --- | --- | --- |
| `static` | `go vet ./...`, `go build ./...` | No database |
| `database` | database preflight, `go test -json -count=1 ./...`, existing no-skip verifier even after a failed Go test | Dedicated PostgreSQL 17.6 service; original two DB environment variables |
| `load` | screen-share profile matrix test; real normal/reconnect/uploads/nat_auth/faults API fixtures | Existing owned Docker stack, provision/cleanup and fixed ports on its own runner; profiles remain serial |

All Go packages, including unit tests and integration/migration tests, stay in
one uncached `./...` invocation. No package-name heuristic partitions or excludes
tests. Static work is separated without pretending that fixture sharing among
individual Go packages has been proven safe. The load profiles retain account
counts 2/2/2/1/2, durations 20/20/20/20/40 seconds and 1024-byte uploads. No PR vs
release reduction, mock API substitution or test-result cache was introduced.

All three restore only the existing public Go dependency/build caches keyed by
approved SDK and dependency inputs. PostgreSQL state, session data, test JSONL
and PASS receipts are not cached. `-count=1` is unconditional.

The stable `backend / backend` job runs with `always()` and requires all three
successful job results plus exactly three complete source/run/attempt-bound
profile reports. Missing, duplicated, failed, skipped, foreign and incomplete
parts cannot produce PASS. The original three-field `check-backend-…` receipt
is uploaded only after this aggregate, and the server producer still requires
that receipt. Deployment routing and required-check settings are unchanged.
Profile artifacts and aggregate durations are public metadata only; no test
stdout, usernames, request bodies or credentials are added. Existing sanitized
load JSON/CSV/HTML retention is preserved.

On a clean checkout with the pinned Python/Go SDKs, Linux Docker and the same
isolated PostgreSQL service/environment as the workflow, run the entire gate:

```sh
python3 -m tools.ci.receipts.run backend
```

For diagnosis run `python3 -m tools.ci.backend_gates.run --profile static`,
`--profile database` or `--profile load`. Local profiles are serial by default;
do not run multiple load fixtures on one daemon/port set. The command runs real
operations. Focused harness tests are separate from actual backend acceptance.

Profile JSON records actual elapsed seconds, source revision and execution.
The one historical run cited by #389 (~8-minute backend, ~4:23 load step) is not
a p50/p95 baseline. Repeated before/after hosted timing and failure/flake-rate
acceptance remain NOT_RUN, deferred to the combined epic validation per owner.
No measured speedup or full hosted runtime PASS is claimed by this change.
