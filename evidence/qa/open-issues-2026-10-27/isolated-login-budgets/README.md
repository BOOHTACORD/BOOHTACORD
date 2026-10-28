# NAT20 / login budgets — I240.C5 and canonical fix137

**FAIL: referenced137 NAT20 availability acceptance remains unmet by the default
network policy.** Two cohorts each give10 successful valid logins and10×429.
Actual source `072426d60b1c0b1f7e5f66722a0da5faa00b50d7`, Go API + PostgreSQL17.6,
observed 2026-10-28 00:10–00:16 UTC. No API/service/KDF mocks or server changes.
The runtime counterexample exits **1** after passing controls and cleanup.
Full QA240 remains FAIL/open. Other upload/platform/media facets remain queued.

| What is protected | Executed command | Platform | Mandatory when | Actual result |
|---|---|---|---|---|
|20 independent valid users sharing one trusted-client source satisfy137 NAT availability without losing account/KDF defenses | `python -X utf8 .out/qa-login-budgets/run_profile.py run` | Windows11 controller; bounded Linux client in own trusted-proxy namespace; actual local API/PostgreSQL17.6 | Before I240.C5/#137 NAT acceptance | `run-result.json`, `summary.json#/facets/NAT20_cohort_A`, `summary.json#/facets/NAT20_cohort_B`: **FAIL**,10×204/10×429 each |
| Account8/30s precedes KDF, normalized login variants share quota, unrelated account stays usable, original window recovers | Same measured command | Same actual API; distinct private source cohorts, own existing MEMBER fixtures | Before account-admission acceptance | `summary.json#/facets/account_budget_distributed_sources`, `account_original_window_recovery`: PASS scoped |
| Source10/300s denials carry Retry-After and do not extend the original window | Same measured command | Unchanged default API policy; real elapsed time | Before source-window contract acceptance | `NAT_window_midpoint_denials`, `NAT_original_window_recovery` facets:150s denial,302s success |
| Process KDF capacity fails fast without queuing credentials; controlled manual retry succeeds | Same measured command |64 independent own accounts,64 concurrent attempts; actual KDF capacity4 | Before this bounded KDF burst claim | `independent_account_KDF_burst`, `manual_KDF_busy_retry`:18×204/46×503 AUTH_BUSY, retry1s PASS |
| Auth/KDF active work drains to0 | `python -X utf8 .out/qa-login-budgets/run_profile.py observe` | Fresh read-only private API after terminal profile | Before publishing result | `observe-result.json`: PASS |
| Login/KDF metric families have only finite decision/outcome/histogram labels | `python -X utf8 .out/qa-login-budgets/run_metric_audit.py` | Actual private API registry | Before claiming identifier-free observed metric families | `metric-label-audit.json`:40 series/19 names, PASS |
| Own sessions revoked; original nine services/private ports/source and bounded log scan remain correct | `python -X utf8 .out/qa-login-budgets/verify_after.py` | Actual local PostgreSQL/Docker plus both log streams | After the profile including a failing acceptance assertion | `environment-after.json`: PASS, all1000 historical own sessions inactive |
| Existing source security/limiter tests remain executable | Exact argv in `focused-go-result.json`, cwd `backend`, `GOTOOLCHAIN=local`, empty `DATABASE_URL` | Go1.26.4 windows/amd64 | Supplemental regression check, separate from NAT20 runtime acceptance |11 top-level PASS,0 skips,17 pass events including subtests |

## Counterexample and policy interpretation

The outer LoginLimiter is10 requests per300s, before account admission8/30s and
process KDF4. Each cohort attempts20 **distinct existing own accounts** once with
correct credentials, sequentially. The first10 get204 with verified secure
cookies and matching actual session identities; the next10 get429 RATE_LIMITED,
Retry-After300, no cookie. Each cohort increments admitted/success/KDF-work counters
by10, so rejected neighbors never enter account work or KDF.

The second fresh source reverses the same20-account order: the previously refused
half now succeeds; the other half receives429. An extra fresh-source credential
control gives204. This isolates shared network admission from invalid passwords
or blocked/expired accounts. It is a **confirmed original137 NAT20 acceptance
gap under this documented profile**, not a credential bypass or permanent ban.

The source limit is intentional in the existing security unit test. The NAT
independence unit only invokes the account handler and checks two users, without
the outer network middleware. Both tests pass and remain unchanged. Passing them
does not prove the referenced20-user scenario. Coordinate an agreed policy and
regression with137; preserve early account/KDF, network, Origin and cookie defenses.
No limit is silently widened to make this counterexample pass.533 verifier-order
protection is a distinct resolved scope and is retained.

The [existing137 acceptance/comment](https://github.com/Egkurilov/BOOHTACORD/issues/137#issuecomment-6052483714)
already requests this runtime scenario. Open-issue duplicate searches found only
QA trackers for NAT and no open LoginLimiter fix; `duplicate-search.json` records
the decision to reuse/reopen canonical137 rather than create a duplicate.

## Passing scoped controls and numerical limits

Eight wrong pairs for one normalized account from distinct sources give401 with
no cookie and exactly8 KDF work increments. Two correct pairs then get429/30s
without another KDF call; a neighboring account on the same source gets204.
Twenty other-account operations do not reset the protected budget. At20.014s it
still refuses with Retry-After10; at32.029s it admits the correct pair without a
persistent lock. This is finite churn, not actual50000-entry store saturation.

At150.013s, both NAT sources still give429 with Retry-After150/151. At302.093s,
both succeed, without clock injection/restart. Timing uses observed client
monotonic elapsed durations; UTC timestamps are retained separately. These real
window controls do not make the original NAT20 batch pass.

The64-account KDF burst produces18 successes/46 AUTH_BUSY503 with Retry-After1
and no denial cookies. Rejected KDF count and not-started refund count each grow46;
active/waiting drain to0. A controlled manual retry after1s succeeds. Capacity
gauge4 is observed; sampled active maximum2 missed the full-capacity instants.
This verifies a bounded process concurrency gate, not an upload deployment rate
budget, database/query capacity or browser/Flutter automatic-retry behavior.

54 API samples,74 periodic DB samples; sampled maxima RSS221081600 bytes (~211MiB),
FD97, DB connections21, KDF waiting0. CPU counter delta3.18s and KDF work delta72
cover initial through final profile snapshots before cleanup. Sampling can miss
peaks; no statistical timing-channel/capacity/QoE conclusion follows.

## Binding, cleanup and reproduction

`source-binding.json` binds the API image, source, toolchain and pre-execution
runner bytes. All23 selected native code/test/config fingerprints also match
remote master8a2cda38; this is not a full-image/master hosted/platform run.
Public runner sources normalize CRLF to LF; manifest binds published bytes.
Restore `runner-source/` into the matching private `.out/qa-login-budgets` folder,
use the unchanged local stand and prior104-member owned WS fixture, then execute
the table commands. The driver derives logical source cohorts from the private
QA network; source keys, credentials and private input files are never exported.
It refuses to rerun a completed measured fixture. A new run needs new receipts.

The64 newly issued own sessions are revoked: owned rows936→1000, active0. All104
existing own members remain unblocked; no users created/deleted or role/block
changes. Normal login/session metadata changes are part of the test. All9 original
services run with restarts0, host publications loopback-only, source unchanged,
health200. Bounded stdout+stderr scans cover this profile's known own credentials
and tokens; only digests/counts/outcomes are public. This is not all-data privacy.

Client:1CPU/512MiB/128PIDs, read-only root, no capabilities/new privileges/ports;
8min deadline, API stops RSS512MiB/FD2048/goroutines8000, DB80 total/64 active.
Logical cohorts exercise the actual trusted-source boundary;20 physical devices,
router NAT, Nginx/WSS and shipping-client UI/retry are separate. Upload account/IP/
deployment rate budgets and live store-capacity saturation stay queued, not
blocked by a missing stand. Production/router/native sessions and43 consolidation
decisions were untouched; all480 original source requirement texts are preserved.
