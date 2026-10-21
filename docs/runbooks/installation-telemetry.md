# Installation telemetry (#336)

New deployments are local-only. Existing OTEL environment variables do not grant
consent for central export. The ordinary API enables the same migration as other
product schema changes. Never copy a production identity into a new independent
deployment without explicitly resetting it.

## Product operator

In Web → Administration → Guild → Installation diagnostics, review the ID, mode,
registration and last gateway acknowledgement. Enter the central public HTTPS
origin, check the consent statement and choose Connect. Secrets never appear in
the UI/API response. Disable stops external telemetry; chat/voice do not depend
on the central registry, Tempo or Prometheus.

The same explicit operations are available inside the ordinary API image:

```sh
docker compose exec api /installation status
docker compose exec api /installation enable https://telemetry.example.org
docker compose exec api /installation disable
```

The enable command is an explicit operator opt-in to aggregate metrics and
pseudonymized traces; it does not send message bodies, attachments, screen/audio,
raw profile names, passwords or authentication tokens. HMAC pseudonyms are not
a promise of complete anonymity. Unknown/unsupported fields stay local.

For an independent database clone, stop its API and optional agent, then run the
offline operator command using that clone's DATABASE_URL:

```sh
installation reset-clone --confirm-independent-clone
```

Restart the cloned API, enroll its new identity and regenerate its local agent
file. Users/channels remain. A restore of the same logical deployment must NOT
reset identity. This runbook creates no backup or snapshot flow.

Missing/corrupt identity requires operator investigation against the existing
database; it is not silently replaced. External export stops, but product routes
remain usable. The public `GET /api/v1/installation` and response
`X-Installation-ID` are nonsensitive. Current clients invalidate queued telemetry
when this header changes, in addition to origin/account/session guards. Legacy
clients are enriched at the authenticated server relay.

## Central owner

Use `docker/observability/fleet/compose.yaml`. Supply a private registry password,
a random credential-signing key (at least 32 bytes) and an independent owner read
token (at least 32 characters), as Docker secret files in a private directory.
Set the required `FLEET_*_FILE` variables and private registry DSN. No embedded or
shared installation write token exists. Keep file permissions compatible with
the nonroot container while keeping the parent directory owner-only.

The gateway binds to loopback port 4320. Put an HTTPS reverse proxy in front of
it that exposes ONLY exact POST `/v1/enroll`, `/v1/traces`, `/v1/metrics` and
`/v1/status`. Apply an additional public IP request limit. Do not expose `/metrics`,
`/read/*`, the registry DB, Collector, Tempo or global Prometheus/Grafana. Use a
separate reserved gateway/registry budget for the product owner's production
installation if it is centrally enrolled; do not share its capacity with public
self-registration. The existing private local diagnostics are independent.

After enrollment, a central operator with direct private registry access can run:

```sh
registry inspect INSTALLATION_UUID
registry rotate INSTALLATION_UUID
registry revoke INSTALLATION_UUID
registry datasources /private/grafana/provisioning/datasources
```

`registry` is the central image's `/registry` binary. Rotation invalidates old
credentials; the installation operator reconnects with the same owner key.
Revocation cannot be bypassed by re-enrolling that ID. Keep the registry and its
credential-signing key persistent. Do not give registry access to outside
operators. Registration/last_seen records are public only to the central owner.

Provision generated per-tenant Tempo datasources and provide
`TELEMETRY_READ_TOKEN` to private Grafana. Use the existing private Prometheus
datasource UID `boohtacord_prometheus` for the fleet Prometheus endpoint. Import
`docker/observability/fleet/dashboards/*.json`. Installation is the first selector
and is preserved in links. Each `t-UUID` datasource has a fixed trusted
gateway URL. Writer credentials cannot read this endpoint. The global metrics
store is owner-only; a Grafana filter is not an ACL for outside operators.

The fleet overview distinguishes registration, revoked and acknowledged-disabled
states. Zero last_seen means never connected; old last_seen means stale, not
server shutdown. Local UI additionally distinguishes exporting/degraded. Gateway
acceptance is not a durability guarantee: verify reads when diagnosing storage.

Metrics and traces retain seven days in the supplied fleet configuration. Local
disable/revoke do not erase already accepted data. Remove retained tenant data
only through an explicitly approved owner storage procedure; no public purge or
automatic backup command is provided. Keep registry ownership tombstones to
prevent a deleted/revoked installation ID from being claimed by another key.

## Optional private SFU agent

API OTLP instruments own API aggregates. Do not scrape/export them again. The
optional agent owns only approved LiveKit private metrics; it never attributes
global SFU counters to users. Generate its private local-only credential file:

```sh
installation agent-config /private/agent.yaml
```

Set PUBLIC_ORIGIN for that command. Mount the generated file through
`deploy/telemetry-agent.yaml` using `TELEMETRY_AGENT_CONFIG_FILE`, alongside the
ordinary deployment Compose. The file uses the private API relay, a local agent
credential and the trusted Origin; it contains no central credential or HMAC key.
The private relay is not exposed by the public reverse proxy. Keep the file
outside Git, mode 0600 or an equivalent protected container-readable secret mount.
Regenerate it after independent clone reset. No foreign `/metrics` port needs to
be made public.

## Verification

```sh
go test -race ./internal/observability/installation/... ./internal/observability/central_projection ./internal/observability/central_gateway ./internal/observability/central_export
python3 -m tools.qa.installation_telemetry.run
python3 -m unittest tools.observability.fleet_dashboards.test_build
```

The owned runner starts only disposable local dependencies and two independent
product databases. It validates real tenant writes/reads, same local identities,
replica series, signed enrollment, rotation/revoke, disabled egress, clone reset
and concurrent initialization. It removes owned resources in `finally` and never
contacts production. The backend database CI profile includes this runner before
issuing a successful source-bound receipt. A failed readiness or missing runtime
test remains FAIL/BLOCKED, even if separate functional diagnostics succeed.

Delivery health: `boohtacord.telemetry.queue.batches` and the monotonic
`boohtacord.telemetry.dropped.batches` observe pending/lost batches without
network work in the collection callback. Loss is visible centrally after
delivery recovers. `boohtacord.telemetry.build.info` carries only a bounded
numeric semantic version (`service_version`) or `unknown`; no arbitrary build
strings become metric labels. Fleet account gauges use max per installation to
deduplicate replicas of the same product database.
