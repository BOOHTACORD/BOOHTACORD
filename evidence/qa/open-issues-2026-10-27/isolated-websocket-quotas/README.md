# Actual WebSocket quotas — I240.C3 / implementation135

**PASS for the exact backend requirement I240.C3** on source
`072426d60b1c0b1f7e5f66722a0da5faa00b50d7`, observed 2026-10-27 23:49–23:55 UTC
(2026-10-28 Moscow). Real deployed Go API + PostgreSQL17.6; no server mocks.
The ordinary **deployment500 / account5 / session2** limits were unchanged.
QA240 remains FAIL/open with defect134 and unfinished criteria. This packet does
not accept the complete implementation135, other platforms, media or capacity.

| What is protected | Executed command | Platform | Mandatory when | Result |
|---|---|---|---|---|
| Concurrent session/account/global reservations reject excess before upgrade; normal close, TCP error and reconnect release capacity | `python -X utf8 .out/qa-ws-quota/run_ws.py resume2` with final retained sources | Windows11 controller; constrained Linux client in the owned trusted-proxy namespace; direct actual Go API + PostgreSQL17.6 | Before accepting I240.C3 | `resume2-result.json`, `resume2-session-row-counts.json` |
| Bounded1/10/100/500 stages,100-client reconnect cycles and revalidation stay within resource stop conditions | Same final profile command | Same isolated standard-limit deployment; private API metrics + aggregate PostgreSQL samples | Before claiming these performed stages | `summary.json#/numeric_observations`, `resume2-database-resource-samples.json` |
| Owned logout closes its socket, revoked token cannot upgrade, sibling session remains usable | Same final profile command | Only one own local test session; no production/native session mutation | Supplemental revocation control; full delivery/SLO gate separate | `resume2-result.json#/records` (`actual_own_session_revocation`) |
| Final active gauge returns to0 and source-bound metrics remain readable | `python -X utf8 .out/qa-ws-quota/run_ws.py observe` | Read-only private API, after terminal profile/cleanup | Before publishing result | `observe-result.json` |
| Own session rows remain unchanged across quota attempts; all936 historical own sessions revoked,104 accounts retained unblocked; nine original services healthy/private | `python -X utf8 .out/qa-ws-quota/verify_after.py` | Actual local PostgreSQL, Docker labels/source/bindings, both log streams | After the measured profile | `environment-after.json` |
| Native limiter/handler/lifecycle metrics regressions remain executable | Exact `command_argv` in `focused-go-result.json`, cwd `backend`, `GOTOOLCHAIN=local`, empty `DATABASE_URL` | Go1.26.4 windows/amd64 | Supplemental native check; not a substitute for the real API profile | `focused-go-result.json`, `focused-go-events.json` |

## Observed protocol and counters

- Session race:20 simultaneous attempts, **2 accepted101 /18 rejected429**.
  Graceful close1→reconnect2 succeeds. Account race:12 attempts over three own
  sessions, **5 accepted /7 rejected**; a sixth attempt on a nonfull session
  also gets429, isolating the account cap. Abrupt close4→reconnect5 succeeds.
- Quota responses have **429 / REALTIME_LIMITED / Retry-After:1**, no101 or
  WebSocket upgrade. Auth middleware can refresh the **identical** existing
  Secure/HttpOnly/SameSite=Lax cookie; token equality and flags are checked.
  The profile creates no replacement tokens or new session rows.
-20 missing-upgrade requests return426 and10 invalid-Origin requests return403.
  No Sec-WebSocket-Accept/101 or accepted-subscription counter increment;
  active remains0. All five account slots can then be acquired again.
-1/10/100 active tiers each held6s. At490,30 concurrent boundary attempts admit
  exactly10 and reject20; an independent extra attempt also gets429. **500 held
  20s**,500 revalidation calls observed, zero revalidation failures. One abrupt
  close frees499→reconnect500. Two100-connection reconnect cycles, each held4s,
  return to0. Dial concurrency is capped at20, so this is a bounded reconnect
  scenario, not an unlimited simultaneous storm or media capacity profile.
- Final-run metric deltas: **828 accepted /47 quota-rejected** connections.
 85 private API metric snapshots and23 aggregate DB samples. Sampled maxima:
  API RSS104,833,024 bytes (~100MiB), FD553, goroutines1051, DB connections21,
  active DB connections1. API CPU counter delta7.77s covers baseline through
  final profile snapshot before cleanup. Sampling can miss short peaks; the
  active-DB value does not establish query concurrency or SQL query count.
- Owned logout returns204; socket closes1008 after14.996s, retry returns401 with
  no cookie, sibling session still upgrades101. This is an observed periodic
  revalidation control, not acceptance of prompt revocation, protected-delivery
  isolation, all revocation triggers or a general SLO.
- Actual owned PostgreSQL sessions **936→936 rows** across final quota profile,
  active312→0 after logout. Earlier two attempts each revoked their312 sessions;
  all936 are now inactive. Original9 services remain running, restarts0, host
  ports loopback-only, health200, source/API image unchanged. No test users deleted.

## Retained controller failures and source reproduction

The read-only prerequisite initially stopped before any API request on an8-vs7
Go-file count guard; its receipt is retained. Two subsequent measured attempts
terminated with exit1 and completed owned-session cleanup. They are controller
contract mistakes, not product defects:

1. `controller-attempts/attempt1/runner-source/`: execute
   `python -X utf8 .out/qa-ws-quota/run_ws.py run`. It creates104 own members and
   312 sessions, then incorrectly forbids Set-Cookie on an accepted handshake.
   The real authenticating middleware refreshes that same token. All312 revoked.
2. Restore `controller-attempts/attempt2/runner-source/` to the same private runner
   directory and execute `python -X utf8 .out/qa-ws-quota/run_ws.py resume`.
   It reuses the104 accounts, issues312 fresh sessions, passes session/account
   races, then incorrectly prohibits Upgrade on426. Pinned coder/websocket1.8.15
   deliberately sends Upgrade:websocket instructions on missing-upgrade426.
   All new312 revoked;624 historical own sessions inactive.
3. Restore final `runner-source/` and execute the final table commands. The
   corrected assertions check identical secure-cookie refresh and426 with no
   successful upgrade/Sec-WebSocket-Accept;429 remains strictly checked.
   Final profile exit0, all own sessions revoked. The104 accounts are reused.

The final helper may also be used on a fresh owned fixture with `run`, but that
produces a new result. The historical936-row postcheck belongs to these three
attempts. Do not blindly rerun a completed fixture or reuse this packet's expected
values as new observations. Retained helpers require the source072 checkout and
existing private local stand; unchanged dependency:
`../local-staging/runner-source/profile_common.py.txt`. Private fixture files
remain local and are never exported. Documentation-network source cohorts differ
between attempts; ordinary server admission limits remain unchanged.

Pre-execution runner hashes for all three attempts and the postcheck match their
retained sources. `source-binding.json` also binds native files/API image/toolchain
and pinned library files. Public source copies normalize CRLF to LF; the manifest
binds published bytes. Six native Go tests pass with zero skips. Raw test/log
streams, account/session IDs, attempted passwords, cookies, private configuration
and binaries are excluded. Only safe events, counts, source hashes and outcomes
are public. Bounded scans cover both stdout/stderr of all9 own services since
attempt1 and all936 own token markers; this is not an all-data privacy claim.

All19 selected native code/test/config fingerprints also match remote master
`8a2cda38bee5a4d8f7988eb4eefbfa176a62c43a`; see
`current-master-source-comparison.json`. This does not replace a full-image or
master-head hosted/platform run. The earlier missing-local-object observation
was resolved by fetching that exact commit without changing checkout or refs.

Resource stops:12min client deadline, RSS512MiB, FD2048, goroutines8000; API CPU
running mean per hold below1.8 cores once at least5s elapsed; DB80 total/64 active.
Client container:1CPU/512MiB/128PIDs,
read-only root, dropped capabilities/no new privileges, no published ports. No
production/router/native session, server configuration or server restart changed.
WSS/Nginx/browser/native retry behavior, general backpressure/replay ACL/revocation
SLO and media/capacity gates require their own evidence. All480 original source
requirements, earlier failures and43 consolidation decisions remain intact.
