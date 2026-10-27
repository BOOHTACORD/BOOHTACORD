# Isolated tracing acceptance, Windows 2026-10-27

Source: `4cfafba325291cd673fe410578c73fe9d36c22c5`. Production source and tests
were unchanged. See source-proofs.json and the immutable native entrypoints.
Reuse `tools/qa/tracing_flow/README.md`; helper copies are in ../runner-source/.
Copy them to their named `.out/qa-goal/` paths. Do not use production endpoints.
The existing private toolchain-paths input must resolve the installed Flutter SDK.

Run trace_fixture.py inspect, pull, up; then trace_runtime.py ready. Inspection
requires a local Docker context, free loopback ports, a fresh namespace, read-only
repository config mounts, bounded CPU/RAM/logs and no selected external network.
The temporary override changes restart/log bounds only; no product code changed.
Use Node/Go/Flutter versions from tools/toolchains.json and native lock files;
Web dependencies were installed using npm ci, not an unpinned npx installation.

Run trace_runtime.py profiles in this order: relay, browser, native, worker,
replay, collector_outage, tempo_outage, relay. Preserve the initial relay receipt
before the final recovery invocation, as this run did. The browser profile uses
installed Chrome in headless mode and takes about125 seconds; its business API
and video are synthetic. Native means Flutter's Windows test engine, not an APK
or installed desktop binary. Do not substitute these results for physical gates.

Outage control checks exact project labels. Only the owned Collector/Tempo are
stopped; finally blocks restore them. Collector outage requires real connection
failure and relay503 within4s, with no accepted receipt. Tempo outage requires
unavailability to be observed before restart, and queryable data within30s.
The recorded5.04s is the test duration, not a measured production recovery SLO.

Run trace_dashboard_runtime.py for the existing nine query-semantic fixtures,
then trace_queries_run.py for dashboard queries over900/21600/86400 seconds.
The first controller incorrectly matched Windows CRLF with a regex ending `$`.
All nine underlying tests finished OK. recover_trace_dashboard_receipt.py reads
that same original log, normalizes line endings and verifies all nine statuses;
no test was rerun or expectation changed. The original child exit was not retained.
The original safe unittest bytes are reconstructable from dashboard-unittest-original.json
(raw_utf8 encoded as UTF8); dashboard-unittest.txt is the LF-normalized text view.

Run trace_cleanup.py after capturing results. It verifies volume/network ownership
and absence of foreign users, removes only this fresh Compose namespace and its
attached volumes, then verifies absence and compares unrelated container states.
No prune, engine shutdown, unrelated stop, backup or production fault was used.

Raw Go/SDK output stays ignored: it contains synthetic correlation identifiers.
Published receipts retain selected test events, assertion outcomes, counts and
hashes only. Each source row remains incomplete until all of its clauses/platforms
pass; local queries do not accept deployed Grafana UID/datasource/RBAC/drilldown.
