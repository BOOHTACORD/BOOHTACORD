# Voice roster dependency isolation

`503` or an unavailable/stale roster describes a failed observation, never an empty room.
R01/R02/R03 clients preserve the last observation and expose a bounded manual retry.
Do not create a Room, capture microphone, or issue a media credential to enumerate members.

## Metrics and privacy

Roster instruments use the existing authenticated OTLP export every 15 seconds.
Central Prometheus scrapes the private Collector; public `/metrics` stays forbidden.
Import `docker/observability/dashboards/voice-roster.json` into the private Grafana
and select its actual Prometheus datasource in the dashboard selector.
The observation-enabled marker distinguishes an idle, instrumented API from absent
instruments. Panels display `Нет данных` for missing series, never fabricated zero.
Successful snapshot age excludes timestamp zero (no observed success).
Labels are fixed stages, outcomes and methods. Never add room,
channel, lease, session, account IDs, display names, tokens or message bodies.

## Read-only incident sequence

1. Record UTC, client version, API image digest/SHA and `X-Request-ID` from one
   authenticated failing request. Exclude Cookie/Authorization headers from evidence.
2. Compare one-shot REST `/api/v1/voice/participants` with the roster snapshot on
   the same account's authenticated application WebSocket. Capture sanitized
   status and timing without recording participant or session data.
3. Isolate `visibility_initial` (DB ACL read), `presence_room_list` / participants
   (private LiveKit), then `visibility_recheck` (DB ACL revalidation).
4. Compare failure counters with initial snapshot timing, active connections,
   RoomService outcome/latency and gate shared/cached/overload/cancel counts.
   Transport failures classify dns/connect/reset/timeout/canceled/other; HTTP
   failures classify 401/403/404/5xx/other. Use those bounded classes before
   checking network namespaces or credentials; never export raw dependency text.
5. Check private DB health/pool pressure and API/SFU shared network membership,
   endpoint DNS, authenticated ListRooms/ListParticipants and deployed revisions.
   Compare direct and proxied requests without exposing management ports.
6. Compare API/SFU restart/OOM counts and pinned digests. A working private probe
   does not prove authenticated REST/WebSocket or device acceptance.

## Alerts and rollout

The `voice-roster-alerts.yaml` rules and dashboard use authenticated WebSocket
subscriber, initial-frame, delivery and coordinator-refresh signals. Initial
blackout requires observed failed or unavailable first frames and no successful
first frames; idle deployments do not trigger it. Delivery blackout detects
observed failed or unavailable frames without successful frames. Refresh blackout
requires active subscribers, 60 seconds without a successful authoritative
refresh, then a sustained five-minute window.
This conservative budget is twelve regular five-second refresh intervals,
not a production capacity claim. Telemetry missing requires API export enabled
but absent roster observation marker. If all API telemetry is missing, use the
existing exporter/freshness incident panels as well; this rule cannot invent data.
Tune additional ratio/p95/calls-per-watcher warnings only after recording a real
baseline and watcher count distribution. Do not set arbitrary capacity thresholds.

Change deployment configuration only when the comparison proves a configuration
defect. Otherwise record `NO_CONFIG_CHANGE`; source fixes require their own packet.
Choose rollback only for a demonstrated release regression, after confirming the
retained release's schema compatibility and signed bundle. Never reset DB/data.

Local SDK-to-central-storage and synthetic alert tests do not establish production acceptance.
Until actual import, scrape freshness and authorized REST/WebSocket recovery are measured,
record that acceptance as `NOT_RUN`; #272 owns the release/device matrix.
