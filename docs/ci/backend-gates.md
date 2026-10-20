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

## Same-source functional comparison (#401)

`Backend same-source functional shadow` (`backend-ci-shadow.yaml`) is a separate
manual, upstream-master-only quality experiment. It has read-only repository and
Actions permissions, no environment, release receipt, signing key or production
mutation. It does not qualify as a server producer.

The sequential arm preserves the eleven original checks and their ordering from
pre-split revision `d552352482187b9822768161f8507d59cbf2e19e`: database preflight,
the complete uncached Go suite, mandatory no-skip verification, vet/build, matrix
and all five API load profiles. It executes the current reviewed helpers and
current product source, not historical code. Its dedicated PostgreSQL service,
SDK pins and load fixture match the normal gate. No failed assertion is retried.
The other arm calls the unchanged normal `ci-backend.yaml` once with
`release_receipt: false`, preserving its three independent hosted machines.

The comparison requires both arms to succeed, the complete eleven-operation
coverage, exactly three profile reports and their successful aggregate. Reports
must match the source, run and attempt; actual GitHub job metadata must identify
the six expected hosted jobs. Missing, skipped, failed, foreign, reduced or
malformed inputs retain FAIL. A FAIL report is initialized before source
preflight and before artifact downloads, so an old PASS cannot survive a
preflight or download failure. Only bounded public JSON is retained for 30 days;
database state and raw test output are not added as artifacts.

This is **one complete paired functional sample**. It records actual job
intervals and runner minutes, including setup and fan-in, without p50/p95,
causal speedup, flake-rate or capacity assertions. Historical before/after
timings from different revisions remain separate observational evidence.
Adding this workflow does not itself prove parity: the actual manual execution
and its original source-bound reports must pass before acceptance can count it.
