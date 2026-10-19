# #389 — backend gate implementation

Implementation separates static/compile, complete uncached PostgreSQL Go tests
and all five real API load profiles into independent hosted jobs. The stable
aggregate keeps the original release receipt contract and requires every exact
source/run/attempt part. Coverage and local commands: `docs/ci/backend-gates.md`.

Focused TDD: missing result/runner modules first produced ImportError; missing
workflow policy likewise failed before implementation. Tests now exercise
missing/foreign/failed/skipped/duplicate/partial parts, retry identity, non-finite
durations, stale PASS replacement, both Go failure and verifier failure, the real
no-skip executable with pass/skip/fail/empty streams, unchanged command inventory,
PostgreSQL isolation and aggregate/workflow bypass rejection. Existing Web
receipt, master producer, Go cache and trust-boundary regressions are included.

Validation results are recorded after the final focused run below. Full Go/DB
execution, all actual load fixtures, hosted runtime and repeated p50/p95 and
failure/flake-rate comparison: NOT_RUN for this implementation. The owner asked
to prioritize implementation with focused checks and defer long repeated runs.
This record does not close that operational acceptance gate.

Final focused run: **32 PASS in 2.381 s** (`backend_gates` results/runner/workflow,
Web receipt, master quality workflow, toolchain workflow and Actions trust).
Workflow policy: **PASS**, 31 workflows and 2 local actions; actionlint 1.7.11:
**PASS**; `git diff --check`: **PASS**. Required spec traceability: **PASS_INDEX_ONLY**,
39 requirements; the approved external brief is unavailable on this host.

## Combined actual acceptance — 2026-10-19

This section supersedes the implementation-only NOT_RUN statement above for the
backend gate itself. Final record: `backend-gates-final-2026-10-19.json`.
Three completed master sources (59c15c65, c569477f, 356d32c5) ran the unchanged
backend recipe: full uncached PostgreSQL Go tests/no-skip, vet/build and all five
real API load profiles. Thirteen additional ZIPs were independently downloaded,
API owner/source/run/attempt, bytes and SHA256 verified; their exact public JSON
payloads are retained in the record. All three complete 11-operation fan-ins
were replayed with the production validator and matched their release receipts.
The current recipe still matches those tested sources. Ten nearest focused tests
passed again in 0.102s; the earlier broader 32-test result remains historical.

The three original #383 server-build samples are hash-bound to the frozen record.
Nearest-rank p50/p95 execution span is 486/514 -> 389/453 seconds; workflow-create
to backend-available is 489/517 -> 608/649 seconds. Occupancy p50 is 486 -> 532
seconds, first backend start delay p50 3 -> 196 seconds. Both cohorts contain
zero observed failed runs, retries or flaky failed-run events out of three.
Intrinsic flaky-test probability stays UNKNOWN. Different historical sources and
runner load prevent a causal same-SHA speedup claim; hosted waits outweighed the
execution improvement. This is a measured limitation, not an omitted result.
Required-status administration (#385), global shadow/cutover (#401) and physical
or media-capacity acceptance remain separate; this evidence does not close them.

Self-contained replay of retained public profile bytes and distributions:

```sh
python - <<'PY'
import hashlib, json, os
from unittest.mock import patch
from tools.ci.backend_gates.results import PROFILES, validate
from tools.ci.baseline.metrics import distribution
r=json.load(open('evidence/ci/backend-gates-final-2026-10-19.json'))
for artifact in r['artifact_verification']:
    for name, text in artifact['payload_utf8'].items():
        assert hashlib.sha256(text.encode()).hexdigest()==artifact['files'][name]
for run in r['runtime_checks']:
    with patch.dict(os.environ, GITHUB_ACTIONS='true', GITHUB_RUN_ID=str(run['run_id']), GITHUB_RUN_ATTEMPT='1'):
        assert validate(run['source_revision'], {p:{'result':'success'} for p in PROFILES}, run['parts'])==run['replayed_fan_in']
for cohort in ('before','after'):
    c=r['measurements'][cohort]
    for field, expected in c['summary'].items():
        assert distribution([s[field] for s in c['samples']])==expected
print('Backend evidence replay: PASS')
PY
```

### Complete after window, including cancelled/red gates

The final record also contains every one of the12 master Build server executions
created17:30:25–20:12:42UTC, independently checked against one complete bounded
GitHub API query (24 matching pushes across workflows,12 server producers).
Eight backend gates PASS, four cancelled children yield an actual red backend
aggregate; no cancellation is counted as a successful test or a flaky defect.
All12 use the unchanged backend gate recipe. Successful-gate timing n=8:
execution p50/p95 350/533s, availability608/1032s, occupancy532/611s and first-start
delay125/682s. Required-gate red/cancellation rate4/12, non-cancelled component
failure0/12, observed flaky failed-run events0 and retries0. Intrinsic flake
probability remains unknown. The smaller n=3 receipt sample above is retained
for source/artifact replay; it is not the full-window failure-rate denominator.
The complete-window figures supersede its after timing for aggregate reporting.
