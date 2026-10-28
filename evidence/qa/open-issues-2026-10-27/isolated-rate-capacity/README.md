# Actual rate-limit store capacity, race and matched measurements — I240.C7

**PASS for exact I240.C7 scope.** Actual source
`072426d60b1c0b1f7e5f66722a0da5faa00b50d7`, default source capacity10000,
limit10/300s, Linux API/PostgreSQL17.6, 2026-10-28 01:07–01:15 UTC.
Measured HTTP process exit0; no source/configuration/server restart or
production/router/device/session changes. QA240 remains FAIL on134/137.

| What it protects | Executed command | Platform | Mandatory when | Actual result |
|---|---|---|---|---|
| Full10000 source store preserves exhausted budgets and refuses unknown keys | `python -X utf8 .out/qa-rate-capacity/run_profile.py run` | Windows11 controller; bounded Linux helper in own trusted-proxy namespace; actual API/PostgreSQL17.6 | Before accepting I240.C7 referenced139 live saturation | `run-result.json`, `summary.json`: PASS, exit0 |
| Concurrent insertion respects exact store capacity | Same live command |16 concurrent distinct source keys at9992 existing entries | Before concurrent-boundary acceptance |8×400 admission,8×429 failclosed; active10000, saturation delta8 |
| Original window recovers and cleanup work stays bounded | Same live command | Real elapsed windows; unchanged actual API | Before expiry/cleanup acceptance |150s429;304s400; first new call removes64 old entries; final155 cleanup calls remove16–64 each |
| Native concurrency, small capacity, exact reset and stale heap nodes remain correct | `python -X utf8 .out/qa-rate-capacity/run_native.py` | Official pinned Go1.26.4 Linux amd64/Cgo container;2CPU/2GiB, networknone | Before I240.C7 race acceptance |12 tests×3 repetitions,36 PASS,0 skips, exit0; original tests unchanged |
| Safety regression detects the known historical eviction defect | Same native command, historical counterexample phase | Exact139 review source ce8c3e0, same Go; method-name adapter only | Before trusting regression coverage | Both safety tests fail as expected on old source, pass on current source |
| Existing/new key cost and contention are compared on matched workloads | `python -X utf8 .out/qa-rate-capacity/run_native.py`; `python -X utf8 .out/qa-rate-capacity/run_hold.py` | Same pinned2CPU container limits, same host, same Go1.26.4 | Before benchmark comparison claim | Four raw benchmark outputs,18 matched cases,3 repetitions each |
| Per-call latency and mutex-held time have measured distributions | `python -X utf8 .out/qa-rate-capacity/run_hold.py`; `python -X utf8 .out/qa-rate-capacity/analyze_native.py` | Explicitly instrumented private historical/current copies, GOMAXPROCS1 | Before held-time diagnostic claim |12 profiles,2000 calls each, p50/p95/p99 in `native-analysis.json`; observer overhead included |
| Fresh metric labels are finite; database/services remain unchanged/private | `python -X utf8 .out/qa-rate-capacity/run_profile.py observe`; `python -X utf8 .out/qa-rate-capacity/verify_after.py` | Read-only actual API/PostgreSQL/Docker and both service log streams | Before publishing result |21 rate series/3 families/7 finite operations; DB counts unchanged,9 services/restart0, health200 |

## Actual API sequence

Fresh logical source keys are private synthetic IPv6 addresses supplied only
from the owned trusted-proxy network namespace. They are not physical NICs or
a public header-spoofing proof. Each request has a one-byte malformed JSON body
and reaches parser400 before account admission, password/KDF work or sessions.
No API/mock/service clock is injected into this live profile.

Sixteen fresh warmup sources naturally clear expired prior entries. One source
consumes10 requests; its11th returns429 RATE_LIMITED/Retry-After300, no cookie.
Four workers, at least10ms between request starts, prefill9992 active keys.
Sixteen concurrent new keys then admit exactly8 and refuse8. The exhausted source
still returns429; a known source with a free budget reaches400 even at capacity.
Two unknown sources failclosed; only unknown full-store denials increase the
saturation counter. Ordinary per-source quota denials do not increase it.

At150.014s, the exhausted source and a new source still return429/Retry-After150.
At304.021s, a new source reaches400 and removes64 expired entries: active changes
10000→9937 including its inserted key. The protected source then recovers400.
After302s from the final boundary admission, all original cohort windows have
expired.155 more new-key calls remove16–64 entries each until all10000 old keys
are accounted for.157 newly created valid windows remain in memory; they retain
normal300s expiry. The stand is not reset to manufacture an empty store.

There are210 API samples and100 periodic database samples. Sampled maxima:
RSS59191296B, FD24, goroutines35, database connections11/active2. CPU counter
delta7.21s over402.674s client elapsed. KDF-work/account-admission deltas are0.
Database counts remain516 users/2065 session rows/50 unrevoked rows/9 attachments;
this packet creates no user, session or file. Existing fixtures remain intact.
These are bounded observations, not a production/media capacity or latency SLO.

## Native evidence and measured limits

The six original tests remain unchanged. Six additional tests use a test overlay:
two shared historical/current safety regressions, concurrent10000 capacity,
64-entry expiry batches, a1ns reset boundary, and stale heap-node protection.
The race detector repeats all12 tests3 times without skips or race reports.
Exact argv, output hashes and actions are retained; both historical safety
assertions fail with their expected messages on the139 review implementation.

The unmodified existing/new benchmark uses100/1000/10000 initial entries,
2000 timed calls,3 repetitions and CPU1/4. New-key cardinality grows by2000
with equal spare capacity in both variants. The contended-existing benchmark
uses the same initial sizes,10000 fixed calls, RunParallel and CPU1/4.
Seeding/setup is outside benchmark timing. Historical `Allow` only forwards to
the original `allow`; source behavior is otherwise unchanged.

At10000 initial entries, medians in ns/op are:

| Workload | CPU | Historical ce8c3e0 | Current072 |
|---|---:|---:|---:|
| Existing key |1|62.38|81.31|
| Existing key |4|66.87|65.04|
| New key |1|81499|280.3|
| New key |4|81273|206.7|
| Contended existing |1|64.31|86.47|
| Contended existing |4|84.35|92.82|

Existing-key results do not uniformly improve. All raw repetitions, allocations
and ranges are retained; these short microbenchmarks do not establish a broad
speedup or productionSLO. Instrumented sequential new-key hold p95 at10000 is
102868→193ns; call-latency p95 is103289→250ns. Those diagnostics add clock/defer
observation to private copies, include observer timing overhead and exclude
waiting to acquire the mutex. They are not direct measurements of the API image
or worst-case contention. The exact instrumentation and hashes are retained.

`native-attempt1/` preserves an infrastructure exit1 with **zero tests executed**:
the test container's tmpfs defaulted to noexec. Only the test mount was corrected
to exec/nosuid/nodev; the full race gate was rerun. No product failure is inferred.

Credentials, real fixture IDs, synthetic source values, quota keys, raw service
logs, binaries and caches remain private. `source-binding.json` checks selected
files against tested source/image and a fresh master snapshot; public LF exports
are sealed separately from original pre-execution byte hashes. The existing
private fixture/common local-runner dependency must be provisioned for replay.
This does not prove50000-account-store saturation, physical NAT/router/native
retry, media/platform/hosted gates.43 consolidation decisions remain untouched.
