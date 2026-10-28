# Upload account/source/deployment windows — scoped I240.C5 evidence

**PASS_SCOPED**, actual source `072426d60b1c0b1f7e5f66722a0da5faa00b50d7`,
Linux Go API and PostgreSQL17.6, 2026-10-28 00:45–00:55 UTC.
The final measured process exited **0**. Full I240.C5 and QA240 remain **FAIL**:
the earlier NAT20 counterexample and canonical fix [137](https://github.com/Egkurilov/BOOHTACORD/issues/137)
are retained. This packet changes no production/native source or limit.

| What it protects | Executed command | Platform | Mandatory when | Actual result |
|---|---|---|---|---|
| Shared TEXT/DM account10, source200 and deployment5000 windows per300s; Retry-After; independent neighboring budgets | `python -X utf8 .out/qa-upload-budgets/run_profile.py resume` | Windows11/Go1.26.4 controller; bounded Linux helper in own trusted-proxy namespace; actual local API/PostgreSQL17.6 | Before accepting upload-window facet of I240.C5/#137 | `resume-result.json`, `summary.json#/facets`: PASS scoped, exit0 |
|16 concurrent admissions cannot exceed the eight remaining global slots | Same measured command | Same unchanged API;16 distinct accounts with free slots | Before concurrent global-boundary claim | `deployment5000_shared_routes_concurrent_boundary`:8×400 admitted,8×429; exactly5000 total |
| Denials preserve original windows and allow natural recovery | Same measured command | Real elapsed time, unchanged server and clock | Before recovery claim |150s probes429; global/account302.053s and source302.009s recover |
| No upload work/reservations/staging remain | `python -X utf8 .out/qa-upload-budgets/run_profile.py observe` | Fresh actual private API/filesystem observation after terminal profile | Before publishing result | `observe-result.json`: inflight/reserved/staging0 |
| Exact own accepted synthetic files have expected metadata and SHA256 | `python -X utf8 .out/qa-upload-budgets/run_file_audit.py` | Own attachment volume mounted read-only; helper network disabled | Before integrity claim | `file-integrity-audit.json`:6 files/192B match |
| Observed upload/rate/attachment HTTP metric labels are finite and identifier-free | `python -X utf8 .out/qa-upload-budgets/run_metric_audit.py` | Actual private API registry | Before observed metric-label claim | `metric-label-audit.json`:39 series/8 families PASS |
| All own sessions revoked, retained files accounted, original services private/healthy | `python -X utf8 .out/qa-upload-budgets/verify_after.py` | Actual local PostgreSQL/Docker and both service log streams | After all attempts including controller failure | `environment-after.json`:2011 historical session rows,0 active;9 services/restart0 |
| Existing nearest security/admission/storage tests remain executable | Exact argv in `focused-go-result.json`, cwd `backend`, local Go toolchain, empty DATABASE_URL | Go1.26.4 windows/amd64 | Supplemental native regression check |7 top-level PASS,0 skips; distinct from deployed5000-window profile |

## Measured outcomes and limits

Account10 is shared across TEXT/DM, source changes and two sessions of one own
account. Two real32B controls return201 and eight malformed requests400;
the11th and another-session probe return429 RATE_LIMITED/Retry-After300.
A neighboring account on that source successfully uploads201.

Twenty distinct own accounts contribute200 short malformed requests to one
source (100 TEXT/100 DM). Fresh accounts on that exhausted source get429;
the same account on a fresh source reaches400. These fillers exercise ingress
window accounting before multipart parsing, not DM authorization or5000
successful file transfers. Valid DM controls use only the two own participants.

After212 handler admissions, four workers with at least10ms between request
starts contribute4780 more400s. At4992, protected account/source probes still
give429 while global capacity remains. This is finite foreign-key churn, not
actual10000/50000-entry limiter-store saturation. Sixteen concurrent boundary
attempts admit8 and reject8; fresh-account TEXT and DM both then get429.
The first5000 admissions consist of **4997 malformed400 +3 accepted201**.
Server invalid_multipart deltas independently match8/201/4780/8 stage counts.

At150.019s, independent global probes still give429/Retry-After150. At302.053s,
a previously unused account reaches400 and own TEXT/DM controls upload201;
at302.009s the previously exhausted source admits400. No restart, limit change,
limiter reset or injected clock is used. Authenticated responses may refresh
the same secure session cookie; equality and Secure/HttpOnly/SameSite are checked.

There are99 API samples and106 periodic database samples. Sampled maxima:
RSS122707968B, FD39, goroutines45, database connections12. These bounded
observations are not calibrated load/media capacity or a latency SLO. Short
requests can fall between resource samples; concurrent outcomes are preserved.

## Retained first attempt and fixtures

`attempt1/` preserves the original runner source, receipts and terminal exit1.
Its first accepted upload201 was followed by an incorrect controller expectation
of download200. The actual owner GET404/NOT_FOUND is **correct** for UNATTACHED
files before a live message links them. `unattached-diagnostic.json` independently
confirms identity/404 and revokes its diagnostic session. No product bug is
created for that controller error. The final run expects UNATTACHED404.

The same504 own accounts were reused; no second400-member creation occurred.
The earlier window expired naturally with30s margin before the independent
ledger.505 first-attempt sessions, one diagnostic session and505 final sessions
were revoked; together with1000 earlier rows,2011 owned sessions are inactive.
400 newly created members remain as isolated fixtures. An empty owned DM and
**six synthetic UNATTACHED32B files (192B)** intentionally remain: one from the
first attempt and five from the successful run. Final volume inventory also
includes three earlier files:9 total/66752B, staging0. This is accounted
retention, not a claim of complete database/file deletion.

`source-binding.json` binds27 selected source/test/manifests to the tested image
and current master snapshot. Original pre-execution Windows-byte hashes and
LF-normalized public copies have separate hashes. Credentials, cookies, source
IPs, quota keys, fixture IDs, payloads and raw logs stay private. Runtime helpers
need the already provisioned private local fixture and the retained
`../local-staging/runner-source/profile_common.py.txt` dependency.

No Android/iOS/macOS/browser automatic retry, physical NAT/router, attached-file
download, media/capacity or hosted CI gate is proved here. Live limiter-store
capacity saturation remains queued. Original43 consolidation decisions stay
untouched; full I240.C5/#137 and QA240 remain open/FAIL.
