# Direct report counter and canonical metric path

One bounded isolated verification, with source classification of the accepted
report path. Source comparisons bind16 exact native/config/consumer files across
Q072, W1a and merged754b. Existing current-CI tests are not rerun.

Commands from Q:

1. python -B -X utf8 .out/qa-agent-counter-path/classify.py
2. python -B -X utf8 .out/qa-agent-counter-path/preflight.py
3. python -B -X utf8 .out/qa-agent-counter-path/run.py
4. After cleanup/window release: python -B -X utf8 .out/qa-agent-counter-path/seal.py

The authenticated handler writes two distinct instrument families:

- http_metrics/client_screen.go updates native private Prometheus instruments,
  including voice_platform_client_screen_reports_total. Direct private API
  exposition is read using wget in the verified owned PostgreSQL container.
- record_qoe.go -> aggregate.Observe records OTEL boohtacord_media_* instruments.
  start_metrics exports at15s, Collector accepts OTLP and exports Prometheus,
  then canonical Prometheus scrapes Collector8889. Canonical QoE fields/dashboard,
  alerts and typed consumers reference this family, not the private native report
  counter. Exactly this bounded consumer set was reviewed.

Canonical Prometheus has five jobs with no API scrape. Collector has only OTLP
receivers, with no Prometheus API receiver. The old native-counter empty vector
therefore has no configured collection path in this profile. This does not prove
counter loss or a broken QoE dashboard consumer. Native incident-snapshot scrape
dependencies documented by the QoE guide are separate from this report counter.

One existing controlled MEMBER account gets one fresh normal API session. A single
no-handle synthetic diagnostic report must receive204 and increment the direct
counter exactly once. After normal logout, the same old cookie's single POST must
receive401 and leave that counter unchanged. Three native exposition captures
remain private; public metadata contains only counts, label keys, hashes and
booleans. The diagnostic numeric field is declared synthetic, not measured media.

Read-only optional observations use the correct OTLP metric name and one owned
visit/flow. Tempo raw private identity/trace data are excluded. Empty metric series
remain absent rather than being converted to a numeric counter zero.

Finally normal logout/protected401 and exact account/public-handle/digest SQL guard
remove only the fresh owned session. Selected14 table fingerprints and nine service
identity/config/start/restart values must match; topology remains57. No new user,
category, channel, lease, chat, RTC credential or connected media is created.
Diagnostic counters/latest sample/private trace remain intentionally; no recorder
reset, reload/restart, canonical config/source edit or entireDB equality claim.

Prior source/correlation/empty-vector artifacts remain frozen. This packet does
not retroactively promote that earlier observation or close a QA/platform gate.
Only the closed public-review.json allowlist may be exported. Raw exposition,
traces, cookies/session IDs/digests, credentials and command logs stay private.

Actual result: PASS_SCOPED. The single authenticated report received204 and
native direct exposition increased3→4. Normal logout followed by one old-cookie
POST received401 and left the native counter at4. The native counter exposes only
the three fixed label keys platform/direction/state.

The correctly named OTLP counter also increased3→4 in actual Prometheus. The
private native-family selector remained absent, represented as None, not zero.
One real owned-flow media.sample span matched authenticated owner/session/visit
with no media-session ID; the rejected flow exported no such span. These are
synthetic diagnostic observations and make no physical quality claim.

One owned session was normally revoked, checked401 and removed by exact guard.
All14 selected baseline fingerprints and nine service/source/prior-packet checks
passed. Topology57 stayed unchanged. No canonical config, service control, new
test execution or product-source fix occurred; no product loss bug is confirmed
in the reviewed canonical QoE consumer set.
