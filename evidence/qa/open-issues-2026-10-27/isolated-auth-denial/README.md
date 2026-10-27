# Isolated login-denial acceptance — I240.C4 / implementation136

Observed 2026-10-27 23:32–23:40 UTC (2026-10-28 Moscow). **PASS for the exact
backend criterion I240.C4** on source `072426d60b1c0b1f7e5f66722a0da5faa00b50d7`.
Parent QA240 stays FAIL/open because of the retained upload defect134 and other
unfinished criteria. No product/test changes or43 consolidation decisions.

| What is protected | Executed command / retained source | Platform | Mandatory when | Result |
|---|---|---|---|---|
| Correct active login creates a valid secure-cookie session; correct blocked login refuses without cookie/session | `python -X utf8 .out/qa-auth-denial/setup_auth.py` | Windows11 controller, actual isolated Go API + PostgreSQL17.6 | Before I240.C4 acceptance | `setup-result.json` |
| Unknown login, active wrong password and blocked wrong password have the same public denial and create no session | `python -X utf8 .out/qa-auth-denial/run_probe.py` (builds and runs retained `probe_main.go` + `probe_http.go`) | Bounded Linux client in the owned trusted-proxy network namespace, direct actual API, actual PostgreSQL | Before I240.C4 acceptance | `negative-profile.json`, `probe-runner.json` |
| Finite timing observations are reported without credentials or login names | `python -X utf8 .out/qa-auth-denial/analyze_profile.py` | Same completed90-request profile | Before any timing comparison claim | `timing-summary.json` |
| Correct login still works after refusals; owned blocked fixture restored and all own active sessions revoked | `python -X utf8 .out/qa-auth-denial/cleanup_auth.py` | Only two newly created owned local MEMBER fixtures and one own admin session | After this packet, including failure recovery | `cleanup-result.json`, `fixture-final-attestation.json` |
| Original nine local services remain healthy/private; bounded owned logs contain none of the scanned credential/login/token markers | `python -X utf8 .out/qa-auth-denial/verify_environment.py` | Existing local deployment, both stdout and stderr since packet setup | Before publishing this result | `environment-after.json` |
| Service/handler credential ordering and cookie behavior remain covered by executable checks | Exact `command_argv` in `focused-go-result.json`, executed with `GOTOOLCHAIN=local`, empty `DATABASE_URL`, cwd `backend` | Go1.26.4 windows/amd64, source072 | Supplemental regression check; actual API evidence is above | `focused-go-result.json`, `focused-go-events.json` |

## Observed profile

90 requests,30 per negative group, concurrency1, minimum request-start interval
1700ms, elapsed151.394s. Twelve documentation-network synthetic source cohorts
keep each source below the unchanged10/5min IP limit. Account budgets also remain
unchanged. The API verifies the trusted TCP peer; the runner attests that its
namespace belongs to the same owned QA proxy and configured trusted CIDR.
This is not an Nginx-forwarding test. No429 or transport failure occurred.

All90 responses: **401 / UNAUTHENTICATED**, one semantic payload SHA256 after
excluding request_id, zero Set-Cookie headers. Actual PostgreSQL counts remain
1→1 across the negative profile: **zero new session rows**. The existing row is
the already revoked positive-control session. The missing-login group was also
attested absent from users; only aggregate counts are retained publicly.

| Group | n | p50 ms | p95 ms | min–max ms |
|---|---:|---:|---:|---:|
| unknown |30|17.168|18.083|16.716–19.573|
| active_wrong |30|17.064|20.570|16.704–33.144|
| blocked_wrong |30|17.187|19.162|16.512–35.210|

Largest group-median difference0.1225ms; ratio1.00718. Quantiles interpolate
linearly at `(n−1)*p`. These30/group observations do not establish constant
latency, statistical absence of a timing channel, remote exploitability or
production capacity. Correct blocked password separately gives403 ACCOUNT_BLOCKED
with no cookie or new session; correct active password gives204 and a matching
authenticated identity before and after the negative profile.

## Binding, preservation and reproduction

`source-binding.json` binds API image, source files, toolchain and original
runner bytes. Pre-execution receipts were retained before each measured phase;
their hashes still match. Public runner copies normalize CRLF to LF; the packet
manifest binds the published bytes. Focused Go checks:6 top-level passes,
12 pass events including subtests, **zero skips/failures**. Public event records
omit raw test output; its private SHA256 is retained.

The retained Python/Go sources are in `runner-source/`. Their unchanged helper
dependency is `../local-staging/runner-source/profile_common.py.txt`. Restore
these sources to the corresponding private `.out` locations in the source072
checkout and use the existing owned local stand/private credential profile.
Run the table commands in order. Setup intentionally refuses to overwrite an
existing fixture: do not rerun it on the completed profile. Stop on unexpected
outcomes, preserve the failure, and restore/revoke only the newly owned fixtures.

The probe has a360s deadline,12s HTTP timeout,64KiB response cap, no cookie jar,
redirects or environment proxy. Its temporary container is read-only, drops all
capabilities, has no new privileges, limits CPU/memory/PIDs and publishes no
ports. The helper is absent after completion. Original9 services remain running,
all host publications loopback-only, API health200, PostgreSQL17.6, restarts0.
No Docker/server configuration, production, router or native-client session changed.

Cleanup leaves two owned local test accounts unblocked, zero active sessions for
them, and revokes this packet's admin session. No other accounts were modified.
Both log streams from all9 owned services were scanned from setup time for the
specific test login/password/session and configured secret markers. Only counts,
digests and outcomes are public. This is a bounded marker scan, not proof that
all logs/data are private. Raw logs, identities, attempted passwords, tokens,
private configuration and the compiled probe binary are excluded.

Nginx forwarding, browser/TLS/native-login paths, other auth quotas, production
load, physical media/acoustic and other platform acceptance remain outside this
criterion. No such gate is closed by this packet. The original480 requirement
texts and all earlier FAIL/PARTIAL/BLOCKED results remain intact.
