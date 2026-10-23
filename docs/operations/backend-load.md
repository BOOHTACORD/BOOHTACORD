# Isolated backend load harness (#8 / T-007)

Run from a clean checkout on **Linux with a local Unix-socket Docker daemon**,
Go from `backend/go.mod`, Python 3.12+, free loopback ports 4810–4812, 4820,
4880–4882, 4890 and 5488. No production address/config is accepted.

```sh
python3 -m tools.load.controller.run --accounts 2 --seconds 20 --profile normal
python3 -m tools.load.controller.run --accounts 1 --seconds 20 --profile nat_auth
python3 -m tools.load.controller.run --accounts 100 --seconds 600 --profile normal
python3 -m tools.load.controller.run --accounts 100 --seconds 120 --profile reconnect
python3 -m tools.load.controller.run --accounts 20 --seconds 120 --profile uploads --upload-bytes 25000000
python3 -m tools.load.controller.run --accounts 20 --seconds 120 --profile faults
```

The controller creates the existing owner-labelled disposable PostgreSQL 17.6,
LiveKit 1.13.7, Tempo OTLP endpoint, Caddy internal TLS and actual Go API fixture.
PostgreSQL uses a private tmpfs. It provisions one administrator and synthetic
`qa_load_*` members in **one deployment**; 1–100 actors map to `(actors+19)/20`
VOICE rooms, never more than 20 logical leases per room. Synthetic hashes copy
the fresh QA bootstrap hash; real production accounts/passwords are never used.
The private account manifest/nonce travels via stdin, not CLI args or artifacts.

Before the first login, the driver verifies the guard's nonce, exact origin,
owner label, commit, freshly provisioned `qa_load_fixture` database marker,
account count and fresh resource snapshot. The guard checks labels before every
container operation and verifies the API executable PID and attachment path.
The driver pins sockets to loopback and refuses redirects. Internal generated
fixture TLS is accepted **only inside this private runner**, not application clients.
The controller removes only resources it created, even after cancellation/failure.

## Workload and safety

Six bounded stages: warmup (one actor), ramp (half), steady (all), spike,
recovery and saturation/stop. At most 75% of the configured overall deadline is
allocated to stages; admission and operations consume the remainder. Per-actor
iteration pauses change actual pressure: warmup 500 ms, ramp 350 ms, steady
250 ms, spike 50 ms, recovery 500 ms, saturation/stop 25 ms. Each phase records
its cadence and observed request rate; these are offered workload settings,
not a product capacity claim. Every actor
retains its own authenticated socket/lease. A write waits for identifier-only
fanout on every active socket, then advances its read cursor. History, search,
topology/members, cookie owner, forbidden admin and a known existing private
DM (admin/member0 pair: member0 allowed; every other actor denied), wrong Origin,
credential issuance, voluntary release, logout and subsequent 401 are exercised.
Normal error/ACL mismatches fail immediately. Request budget is 100,000 per run;
time budget 10–7200 seconds, plus at most 15 seconds for final cleanup.

Automatic guard stops: API CPU >90% of host CPU capacity, RSS >1 GiB, attachment
free space <512 MiB, missing process/ownership, stale (>5 seconds) or unavailable
snapshot. All thresholds are **harness stop limits**, not approved product SLOs.
Cleanup release/logout remains permitted after the workload request budget ends.

`reconnect` closes and resumes all active WebSockets concurrently during spike;
it consumes replay before presence-ready, records replay/resync separately and
reloads protected state after resync. It does not close or claim media recovery.
Each independent actor binds a distinct 127.0.0.x source address: production
login limits stay intact. This represents independent sources, **not** 100 logins
behind one shared NAT; `nat_auth` tests that quota separately: ten logins/logouts from one source,
then an expected 429 RATE_LIMITED with a positive Retry-After.

`uploads` sends up to four concurrent files during steady and spike, binds them
to real messages, downloads them and checks SHA-256 of the complete synthetic
byte sequence. A separate 25,000,001-byte multipart request must receive 413.
Maximum accepted volume for this profile is 200 MB; a 32 MB fault file cannot
exhaust the host filesystem. Reservation/free-space failure is separately covered
by the project's [upload-reservations harness](../../tools/qa/upload_reservations/run.py).

`faults` injects, separately by stage: a two-second exclusive users-table lock
to create real pool pressure; paused owned LiveKit; paused owned Tempo OTLP
endpoint; 32 MiB written to the private attachment volume. Each automatically
restores after two seconds; recovery and final cleanup also restore. This models
dependency loss/backpressure, not unbounded disk exhaustion or production chaos.
Fault-stage errors have a bounded four-errors-per-actor budget; recovery must pass.

## Evidence and limits

`.out/backend-load/<profile>/report.json` plus `routes.csv` and standalone
`report.html` graphs contain safe route names, observed
status codes, total/error counts, p50/p95/p99 for the last 6000 samples per route,
phase active counts, CPU/RSS/free space and fixed-name label-free private metrics.
Passwords, cookies, JWTs, message bodies, usernames, DM IDs, storage paths and
raw HTTP/SQL errors never enter the report. Source revision/API binary hash and
fixture versions identify the run. Missing metrics are absent, never inferred.
The Linux CI smoke retains only this aggregate report; private inputs/API logs
and database/container contents are not uploaded.

Only message→WebSocket p95 ≤500 ms is evaluated from this driver. The brief's
voice join ≤3 s, stream switch ≤2 s and voice recovery ≤10 s stay **NOT_RUN**.
Logical leases/credential issuance do not prove 100 ICE-active participants,
actual packet loss/RTT/bitrate/throughput or Windows/macOS moving capture quality.
Use the separate real SDK/SFU entrypoint `python -m tools.qa.client_lifecycle.run
--critical`, followed by the approved hardware/media capacity gate. No RTP/RTCP
passes through Go. Target hardware/network inventory and capacity remain NOT_RUN
until actual release-gate evidence is recorded; do not extrapolate this smoke.

Protocol regression checks:

```sh
cd backend && go test ./internal/load/... && go vet ./internal/load/... ./cmd/backend-load
cd .. && python3 -m unittest tools.load.guard.test_guard tools.load.provision.test_provision
```


## Authentication quota composition (SEC-001)

`nat_auth` retains one source, ten admitted auth attempts and an eleventh
`429 RATE_LIMITED` / positive Retry-After. It uses eight successful logins with
logout, then two fresh synthetic unknown logins expecting generic 401, and a
third fresh login for the denied eleventh request. This prevents the independent
8-attempt / 30-second account budget from hiding the 10-attempt / 5-minute IP
budget. Expected statuses stay in the report (204x8, 401x2, 429x1), and any earlier
429 or other unexpected response fails the gate. Account-budget concurrency,
cancellation and rejection-before-verifier have their separate SEC-001 tests.
