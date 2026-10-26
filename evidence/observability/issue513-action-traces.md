# #513 — action traces and telemetry delivery

Date: 2026-10-22. Source baseline: `bb51c0d28c0ccc70823a78a7c534fc898aecc845`.
Final source revision and publication receipts must be attached to #513 after
integration. No user messages, credentials, real trace identifiers, or raw
production exports are included in this record.

## Read-only deployed baseline

- Grafana 13.0.2 (`3fcdbc5a`), org 1, UID `boohtacord-traces`, dashboard
  version/generation 13, resourceVersion `1790842200468009`, updated 2026-10-01.
  It is editable and not provisioned. The original classic/v2 definitions are
  retained in the protected, ignored local `.out/issue513` directory for rollback.
- Tempo 2.10.3 (`4aeafc237`), Prometheus 3.11.2, Collector 0.161.0.
  Live datasource UIDs match `boohtacord_tempo` and `boohtacord_metrics`.
- Three live Prometheus targets were healthy: application Collector exporter,
  Tempo, Prometheus. No Collector self scrape, API scrape, or SFU scrape existed.
  The monitoring host and application host have separate Docker networks.
- Tempo searches: 15m 0 traces / 25ms; 6h 0 / 6ms; 24h 500 / 411ms.
  The 24h search reached its limit and is not a complete traffic inventory.
  Production spans/minute and bytes/minute improvement are therefore unproven.
- Actual API configuration points local diagnostics at a public OTLP origin;
  the installation's existing private-destination guard rejects that address.
  An isolated ten-minute log scan counted 80 matching rejection messages.
  The installation is `local_only`; central registration/export is disabled.
  Do not fix this by weakening the private guard or silently enabling consent.

## Completed checks

| Check | Result | Actual scope |
|---|---|---|
| Backend race suite | PASS | Observability, presence, authenticated session packages; subsequent relay fixes have focused race regressions |
| Web focused regressions | PASS | Final 39 tests; presence errors, cancelled/timeout outcomes, stale nested context, session-response acceptance |
| Web production compilation | PASS | Existing deployed public-origin build input; no release publication implied |
| Flutter focused regressions | PASS | Final 19 tests plus changed-file analysis; nested stale action/processor boundaries; opt-in runtime checked separately below |
| Actual Web SDK/components → relay → Collector → Tempo | PASS | Existing opt-in runtime, mounted-render terminal, synthetic principals/data |
| Actual native Flutter engine → relay → Collector → Tempo | PASS | macOS host engine and real frame observation; not a packaged mobile/device media acceptance |
| Relay sanitization → stored Tempo trace | PASS | Allowed identity/platform/flow/cause retained; rejected records, secret attributes and untrusted causal proof removed |
| Relay source metrics → actual Collector | PASS | Web accepted/freshness separated from iOS rejected/unavailable source; bounded labels |
| Ten-minute presence workload | PASS | 605.001 seconds; before/after run concurrently with the same actual HTTP presence handler, TTL store, sampling and batch settings |
| OTLP metrics → Prometheus storage | PASS | Counter suffix, histogram seconds/count/buckets, arbitrary resource-label exclusion and absence of application `target_info` |
| Collector configuration | PASS | Pinned 0.161.0 parser; bounded queue/retry, explicit allowed resource labels, separate private self-metrics |
| Remote-monitor profile | PASS | Actual Compose render and Promtool 3.11.2; no cross-host Docker network or public API/SFU scrape invented |

The full synthetic measurement is
[`issue513-presence-policy-2026-10-22.json`](issue513-presence-policy-2026-10-22.json).
124 HTTP completions per phase produced 124 versus 4 stored traces and 60,226
versus 1,742 OTLP HTTP body bytes. Real first-view/stop transitions, 503 and a
one-span pre-authentication 401 remain stored. Presence counters and duration
observations remain 121 successful/1 failed PUTs. This isolates export policy;
it does not estimate production storage, network headers, or sampling effects.

## Actual failure and query checks

- Eight Collector → Tempo semantic scenarios passed, covering account/visit
  separation, late terminal/full trace lookup, orphan starts, six outcomes,
  short single spans, pre-auth failures, identityless workers and legacy
  clients/media. The first full run passed six cases and exposed the unsupported
  pre-auth nil predicate; after correcting the query, the targeted pre-auth and
  added legacy cases passed. This is not reported as an initially green run.
- 35 dashboard queries × 15m/6h/24h = 105 successful executions on the pinned
  runtime, with two 64-character pseudonyms and multiselect scope filters.
  Compact spanset filters avoid the actual Tempo lexer limitation. A missing
  terminal in block-local search is a candidate for inspection, never a
  definitive failed action; full trace lookup can contain the late root.
- A transient owned Tempo outage retained a relay-accepted trace and made it
  queryable 7.06 seconds after recovery. With Collector unavailable, the relay
  returned 503 instead of accepting the trace. With Tempo unavailable through
  retry expiry, `otelcol_exporter_send_failed_spans` increased after 28.27s;
  the sentinel remained HTTP 404 after recovery. Acceptance is not persistence.
  These failures affected only the isolated QA stack, not production.

## Restored deployed delivery

The existing `local_only` mode and private-destination guard remain enabled;
central registration/export and user consent were not changed. The public
endpoint misconfiguration was replaced with a private Docker-bridge listener
on the application host. A pinned-host SSH channel carries only OTLP to the
same owner's monitoring Collector. Its private key was generated and retained
on the application host; it was never downloaded or added to this repository.

The dedicated monitor account cannot execute shell commands, open remote
forwards or forward to other destinations. Actual probes returned OTLP HTTP
200, denied shell and remote-forward requests, and confirmed no public
listener. Existing root/operator SSH effective settings were unchanged.
Systemd has bounded keepalives, restart and a checked bridge binding. See
`docs/runbooks/telemetry-private-link.md` for installation and rollback.

The live monitoring profile was applied as config revision
`1337e0e02f84de0541c1`, retaining data volumes, pinned images, private bindings
and original definitions for rollback. It adds Collector self-health and
bounded resource labels; it does not invent cross-host API/SFU scrapes.
Only the API telemetry endpoint changed in canonical and active deployment
configuration; the running API image/source remained `bb51c0d28c0c`.

After restoration, actual Prometheus queries found 28 application metric
families and a fresh API collection age of 19.59 seconds. All four targets
(application exporter, Collector self, Tempo and Prometheus) were up. A bounded
15-minute Tempo search returned five fresh application traces. Raw private
responses and configuration receipts remain ignored under `.out/issue513`.

## Dashboard publication and remaining acceptance

The existing org 1 / UID was updated from version 13 to 14, restored to the
original definition at version 15, then republished and corrected through
version 18. Both rollback and final readback matched their exact canonical
source (excluding only server id/version). The dashboard permission response
hash remained `dcb32fb28f059097a4843f957e8cf78855b4436ffaee9ebc714865d0c2ce0c4f`.
No datasource UID, folder, access policy or retention was changed.

Actual deployed query checks passed 105/105 each for All, selected synthetic
scope, and long multiselect (two 64-character pseudonyms): 15m/6h/24h. Maximum
observed latency was 1582ms for the All run, 580ms scoped, and 701ms long. This
is a bounded measurement, not an SLO or complete history. Variable discovery
and tag values passed 30/30. When a time window contains no such attribute,
Grafana 13's native LabelValues can report 'Scope for tag not found'; that is
missing data, not an absent user or a healthy zero. Refresh after activity or
use the scoped session/visit tables. No fabricated tags were inserted.

The UI check caught a real discrepancy from a hand-rendered query: Grafana
`:regex` escapes punctuation once, while a quoted TraceQL literal needs another
layer. Interpolated patterns now use Tempo-supported raw literals, verified
with dotted operation/version and plus-sign version values. Compact producer
fallback avoids the deployed Tempo lexer boundary defect for long selections.

The live UI showed two terminal attempts of one synthetic flow: timeout at
first_frame/deadline, then success. The problems view contained only timeout;
session → visit table links reset descendants, flow opened four actual
start/terminal records, and its Span ID opened the stored two-span Explore
waterfall. Time/org and identity scope survived. The pre-auth problem query
also retains HTTP 401/status-Unset, without classifying a denial as a failed
action. Private screenshots remain under `.out/issue513`; no real user data
was published. Anonymous dashboard API access remained HTTP 401.

The actual local Prometheus scrape stored all six relay metric families (41
series), distinguishing accepted Web from unavailable/rejected iOS; source
freshness was not copied to the failing source. Full details and sanitized
deployed-query receipts are in `issue513-delivery-2026-10-22.json`.

The broad Python verification passed 1267 tests (8 opt-in skips). The first run
without the task's proxy/Docker environment failed local HTTP helpers and
Compose; those environment failures were corrected before the passing run.
The legitimate Prometheus change also received a new source-only LiveKit
network receipt; historical physical evidence was preserved. Physical mobile/
Windows media acceptance is NOT_RUN and is not inferred from the macOS Flutter
engine check. No capacity claim is made.
