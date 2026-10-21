# ADR-028: opt-in installation-scoped external telemetry

Status: implemented for #336; physical media acceptance is unrelated.

One deployment remains one guild. The central registry stores installations and
telemetry policy, not global application accounts, memberships, or messages.

## Identity and privacy boundary

Migration 0054 creates exactly one PostgreSQL identity under an advisory
transaction lock: UUIDv4, a private pseudonymization key and an independent
Ed25519 enrollment seed. Re-running migration does not repair a missing row by
inventing an identity. API startup continues with external export disabled when
identity is unavailable. Every API process has its own random service.instance.id.

Restarts, domain/IP changes and moving the same database preserve identity.
Independent clones require the explicit offline reset command. Reset changes
identity and both secrets, disables export and removes enrollment credentials;
product accounts/channels are untouched. No backup/snapshot mechanism is added.

The existing local OTLP diagnostics remain available to the explicitly local
Collector boundary. External delivery has a separate deny-by-default projection.
Only approved resources, finite operation names/route templates, contract enums,
bounded numeric fields and installation-scoped correlation pseudonyms leave the
server. Events and free status text are removed; unknown protobuf fields are
discarded. User/session/flow/media identifiers never become metric resources or
labels. Client resource identity cannot replace the server's installation ID.

HMAC pseudonyms use separate domains for users, sessions and other correlation
classes. A separate domain-derived causal signing key replaces transport auth
as the proof key. Transport credential rotation preserves pseudonyms and causal
proofs created with this identity. Historical proofs signed with the old shared
transport credential are not upgraded into trusted new proofs; they must be
re-established through authenticated current flows. Trace/parent/span/link IDs
are preserved inside a tenant.

## Registration, isolation and delivery

External export defaults to local_only. An administrator must explicitly consent
to metrics and cleaned traces and select a public HTTPS origin. TLS validation,
DNS/public-address checks, redirect refusal and HTTP deadlines remain enabled.
The installation signs a timestamped one-time enrollment nonce. The registry
binds that ID to the first verified public key; a different key cannot reclaim it.
Write credentials are installation/epoch-bound. Revocation does not affect other
installations; rotation requires re-enrollment by the same owner key.

The gateway derives the tenant from its authenticated registry record, rejects
conflicting payload identity and creates upstream requests from scratch.
Sender tenant headers are never forwarded. Traces go directly to private Tempo,
with exactly one authenticated tenant per request. There is no cross-tenant
Collector trace batch. Metrics use trusted installation/service/process labels
and a finite metric/label allowlist before the private Collector/Prometheus path.

Each API export queue is memory-only: 32 batches, 16 MiB total, 2 MiB per batch,
60-second age, three bounded attempts and a 30-second circuit break after five
failed deliveries. No durable telemetry spool, media storage or exactly-once
claim is introduced. Disabling export flushes pending batches and cancels active
delivery; other replicas re-read persisted policy before delivery. A best-effort
authenticated disable notification informs the registry; without acknowledgement,
the central view must report stale data rather than infer disabled/shutdown.

Gateway ingress additionally bounds decompressed input (compressed requests are
rejected), records/points, strings, timestamps, request/byte budgets and series
cardinality. The product owner's existing private diagnostics remain separate
from untrusted external registrations and their capacity quotas.

## Reading and migration

Write credentials grant no trace reading. The owner provisions one Tempo
datasource per registered installation through a private read gateway. A user
dashboard variable never supplies an unvalidated Tempo header. The owner-only
fleet views scope installation → user → session → visit/flow/media. Existing
dashboards stay explicitly local/legacy; unknown historical data is never
backfilled to the current installation.

Tempo 2.10.3 supports HTTP tenant ingest and read headers. The implementation
uses separate validated per-tenant reads, not implicit cross-tenant federation.
Prometheus resource-to-label conversion is disabled in the fleet Collector.

Sources: [OpenTelemetry service semantics](https://opentelemetry.io/docs/specs/semconv/resource/service/),
[Tempo multi-tenancy](https://grafana.com/docs/tempo/latest/operations/manage-advanced-systems/multitenancy/).
