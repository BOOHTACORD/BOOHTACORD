# Backend incident signals

Import `docker/observability/dashboards/incidents.json` into Grafana and select the private Prometheus datasource. No infrastructure or production change is made by this PR. The existing collector-only scrape (`boohtacord-otel-metrics`, collector 0.161.0) receives mirrored OTel instruments. Private API `/metrics` still exposes the native `voice_platform_*` names. Do not publish that endpoint or database/LiveKit management ports.

## Read freshness before values

Check collector `up`, `time()-timestamp(up)`, then `time()-boohtacord_incident_api_collection_timestamp_seconds`. The API records collection time before export, normally every 15 s. Collector up alone can mean cached API data. Treat collection age >45 s or absent as unknown. Dashboard noValue is `No data / unobserved`; no null-as-zero or `or vector(0)` is used.

`boohtacord_incident_last_attempt_timestamp_seconds`, `last_success_timestamp_seconds`, `last_successful` and `stale` have only fixed operation labels. Exporter `boohtacord_incident_enabled{operation}` distinguishes intentionally disabled (0) from configured (1), without publishing endpoints or credentials. First successful timestamp is absent until success. Failure retains last success, sets latest result 0; stale 1 means no successful attempt or age exceeds probes/workers 45 s, exporters 180 s, other on-demand operations 300 s. An idle relay/on-demand operation can become stale without failure. For collector outage inspect native equivalents locally; exporter failures can only reach the collector once delivery recovers. API collection age continues to expose stopped delivery even while the collector caches earlier result gauges.

Scheduled probes run at startup and every 15 s under runtime shutdown cancellation, each with a 3 s deadline. LiveKit uses the existing private `Ping` ListRooms call, without participant fan-out; storage checks the existing filesystem snapshot and rejects invalid byte ranges. They do not change liveness/ACL or prove media capacity. Final/interim HTTP status, streaming response flushing and real WebSocket behavior are covered by combined middleware wire tests. Storage non-Linux unsupported snapshots report failure, never a healthy zero.

## Route diagnosis and request correlation

Native `voice_platform_api_requests_total` and `voice_platform_api_request_duration_seconds` now label `method,route,status`. Registered ServeMux templates remove the method prefix, for example `/api/v1/channels/{channelID}/messages`; all unmatched URLs collapse to `unmatched`. Method is a standard HTTP enum or `OTHER`; status is 100–599, invalid/panic maps 500. OTel mirrors are `boohtacord_incident_http_requests_total` and `boohtacord_incident_http_duration_seconds_bucket`. Select method/template and compare 5xx rate and histogram p95 without Tempo. A rejected Origin still resolves the registered template before routing. Panic is counted and rethrown. WebSocket duration is connection lifetime, not handshake latency; use existing connection-ready/event-delivery metrics for those incidents.

Copy server `X-Request-ID` from the response. Incoming client values are ignored. The same UUID appears in the safe local `http.request.completed` access event (`request_id`) and HTTP span attribute `request_id`. In Tempo use `{ span.request_id = "<response UUID>" }`; search local JSON access logs for that exact UUID. Neither logs nor the span contain URL/query/body/cookies/credentials. Sampling, exporter outage and deliberately excluded operations can leave no HTTP span. Access logs are local and rotated; there is no centralized logging stack. Request ID is not a Prometheus label.

## Excluded operational paths

All listed paths still bypass HTTP spans and access logs. Safe completion aggregates now use fixed `operation,method,status` on native `voice_platform_operational_requests_total` / `duration_seconds`, mirrored as `boohtacord_incident_operational_requests_total` / `duration_seconds`. These metrics use a fresh background context without a trace/session/request ID. Authentication/rate-limit/Origin denials are counted because observation surrounds the existing middleware. Metrics describe HTTP completion, not semantic content acceptance.

| Path | Fixed operation | Equivalent signal and limits |
| --- | --- | --- |
| `/metrics` | `metrics_scrape` | completion status/latency; current scrape count appears at next scrape, since capture completes after response |
| `/api/v1/health` | `health` | completion status; liveness is unchanged and does not imply dependency readiness |
| `/api/v1/maintenance` | `maintenance` | completion status/latency; no maintenance content logged |
| `/api/v1/maintenance/events` | `maintenance_events` | stream completion status/lifetime; open streams have no completion yet |
| `/api/v1/auth/session` | `session_probe` | status/latency including 401; no identity/cookie/session context |
| `/api/v1/telemetry/traces` | `trace_relay` | completion status/latency and `relay_export` outcome/freshness; existing sanitized relay counters retained |
| `/api/v1/voice/screen-metrics` | `screen_report` | status/latency including rejected reports; existing accepted anonymous QoE metrics retained |
| `/api/v1/voice/rosters/events` | `roster_events` | stream completion status/lifetime; existing roster snapshots/failure stage/RoomService counters cover ongoing work |
| `/internal/media-admission` | `media_admission` | completion status/latency including denied hooks; no tokens/bodies |
| `/internal/livekit/roster` | `roster_hook` | completion status/latency; existing roster/reconciliation signals retained |

## Database and key operation coverage

`voice_platform_database_pool_{acquired,idle,total,max,constructing}` are current native pgxpool statistics. `acquires_pending` measures in-flight attempts including construction; pgxpool does not expose exact waiting-only count. Cumulative `empty_acquires_total`, `empty_acquire_wait_seconds_total` measure successful acquires that waited for release/construction; canceled count is separate. `voice_platform_database_acquires_total{outcome}` and acquire-duration histogram include success/failure/timeout/canceled (context or net timeout), with no SQL, DSN, error string or connection labels. Collector mirrors: `boohtacord_incident_database_pool{stat}` (current gauge), `database_pool_events_total{stat}` (empty/canceled observable counters), `database_pool_empty_acquire_wait_seconds_total`, `database_acquires_pending`, `database_acquires_total`, `database_acquire_duration_seconds_bucket`. Compare acquired/max, pending, acquire p95 and failures; use rate on the cumulative successful empty-acquire wait counter.

With the session partition enabled, the existing pool statistics remain the sum of both partitions. Use `voice_platform_database_partition_connections{partition,state}` to compare `acquired` and `max` separately for the fixed `main` and `session` partitions; a one-connection deployment reports `shared`. The OpenTelemetry equivalent is `boohtacord_incident_database_pool_partition{partition,stat}`. These bounded labels never identify an account or connection. A low aggregate utilization does not rule out a saturated main partition.

`voice_platform_incident_operations_total` / operation-duration histogram and OTel `boohtacord_incident_operations_total` / `operation_duration_seconds_bucket` cover fixed operations:

- `livekit_list_rooms`, `livekit_list_participants`, `livekit_other`, `livekit_remove`: transport latency/outcome; body decode errors are reflected by higher-level snapshot/probe result. Existing SFU/roster counters remain.
- `livekit_probe`, `storage_probe`: scheduled bounded dependency availability/freshness; `livekit_snapshot`, `storage_snapshot`: existing native scrape snapshot calls, on demand.
- `trace_export`, `metric_export`: SDK exporter attempts; `relay_export`: complete collector response/read/decode validation, partial rejection recorded as failure while existing client response semantics remain.
- `lease_notification_worker`, `channel_finalization_worker`, `sfu_revocation_worker`: each background attempt. Existing revocation confirmed/pending/failed counters retained; an expected pending batch is a completed dispatch attempt, not transport failure.
- `realtime_journal`: durable append attempts, including failure; no event kind, recipients, DM or message contents. Existing realtime connection/reconnect/delivery signals retain their roles.

Full LiveKit snapshot counts mirror as `boohtacord_incident_livekit_snapshot{stat="participants|streams|screen_streams"}` only when the existing native snapshot is called. They retain last-good values: gate using fresh API collection, `last_successful{operation="livekit_snapshot"}=1` and success age<45 s. The current collector-only deployment does not scrape API `/metrics`, so this mirror is normally absent. This is an explicit diagnostic blindspot; the scheduled Ping covers dependency availability without extra participant fan-out. No value is a media capacity claim.

## Validation boundary

Focused tests cover bounded route/method/privacy, panic and Origin rejection, server request ID correlation, pool cancellation/stats in both transports, operation freshness, export failure, OTLP payload delivery, dependency deadlines/invalid snapshot rejection, preserved LiveKit/relay/realtime/worker behavior. Pinned Collector 0.161.0 protobuf-to-Prometheus names and dashboard PromQL syntax (Promtool 3.11.2) are verified locally. The guarded saturation integration test runs against the disposable PostgreSQL service in native CI; locally it skips because test database variables are absent. Production dashboard import, live dependency outage and runtime rollback remain NOT_RUN. No APK/Windows build or deployment is included.

## Realtime event delivery stages

Private API metric `voice_platform_realtime_event_stage_seconds` has only two
fixed `stage` values. `before_handler` measures from event `occurred_at` to
entry into the socket event handler, including journal publication and queue
wait; `handler` measures from handler entry through authorization, optional
correlation and a successful WebSocket write. Only successful writes are
observed; neither histogram alone isolates database, network or client time.
Compare counts and traffic before interpreting the distributions. These native
Prometheus metrics require an API scrape; they are not a claim that the OTel
collector or a production dashboard exports them. Production scrape and alert
validation remain NOT_RUN.

## Realtime migration capability claims

`voice_platform_realtime_capability_connections_active` and
`voice_platform_realtime_capability_connections_total` count accepted
**authenticated sockets** with fixed `capability` values `both`, `neither`,
`roster_only`, and `maintenance_only`. They describe the two features claimed
by the connecting client, not its identity, installed version or actual feature
health. Totals include reconnects; do not interpret a socket fraction as the
fraction of installed clients. No capability value grants access. Validate
collector ingestion and scrape freshness in the target environment before
using these signals for release decisions; the version manifest, update-required
experience and compatible cutover remain separate gates.
