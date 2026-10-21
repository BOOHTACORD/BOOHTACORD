# #336 — installation-scoped telemetry

Date: 2026-10-21. Leaf: IT-001, dependency T-052.
Implementation base: `07a73cec706c5e54b88fea17bdfb6e5a02f46a16`.
Status at the local checkpoint: implementation present; functional integration
PASS; full local readiness/acceptance BLOCKED. Final PR CI is recorded separately.
No production mutation, capture, media recording or real-user data was used.

## Delivered

- Persistent singleton installation UUID, independent pseudonym/enrollment secrets,
  process UUID, offline clone reset preserving product data, corruption fail-closed
  for external telemetry without failing product startup.
- Separate local diagnostics and strict central OTLP projection; authenticated
  client principal enrichment, matching per-installation user/session pseudonyms,
  independent causal key and installation-aware Web/Flutter queue invalidation.
- Ed25519 enrollment, registry owner binding/nonces, epoch write credentials,
  rotation/revoke, trusted Tempo tenant routing and owner-only scoped reads.
- Explicit opt-in Web administration and operator commands, bounded disposable
  queues/deadlines/retry/circuit breaker, cancellation/flush on disable, safe
  registration/delivery state and persisted last acknowledgement.
- Optional private SFU agent path, allowlisted instruments/labels, per-installation
  cardinality/rate budgets, fleet Collector without resource-to-label conversion,
  private storage Compose, per-tenant datasource provisioning and scoped dashboards.
- OpenAPI metadata/admin endpoints and backward-compatible installation header;
  deployment-specific DNS/IP override removed from the shared product Compose.

## Actual local integration

Runner: `python3 -m tools.qa.installation_telemetry.run`.
The diagnostic rerun explicitly retained readiness as FAIL/BLOCKED while testing
functional writes/reads; it did not replace the health response with a success.
Receipts/logs are ignored under `.out/installation-telemetry-336/`.

| Check | Result | Evidence boundary |
| --- | --- | --- |
| Independent PostgreSQL A/B identities; restart/read persistence | PASS | Actual separate product databases, same synthetic account UUID/login in both |
| Eight concurrent first-initializations | PASS | Production 0054 SQL, one retained row |
| Signed enrollment through verified TLS | PASS | Production gateway and real registry PostgreSQL; fixture CA trusted, no TLS validation bypass |
| Credential A with installation B body; sender-supplied tenant header | PASS | B body rejected; trusted tenant derived from credential |
| Identical trace/span IDs stored and queried in A/B tenants | PASS | Actual Tempo 2.10.3, independent owner read paths, distinct user pseudonyms |
| Authenticated client relay and server user correlation | PASS | Production relay with a synthetic authenticated principal; injected user claim stripped; actual Tempo contains cleaned client and server signals |
| Ordinary OTel SDK → bounded queue → gateway | PASS | Production tracing exporter and process resource; asynchronous delivery observed |
| API metrics from two A replicas and separate B | PASS | Actual Collector 0.161.0 / Prometheus v3.11.2; installation/process labels, no user labels |
| Private SFU metrics for A/B | PASS scoped | Two actual LiveKit v1.13.7 processes, real `/metrics` reads; approved room gauges passed through authenticated local agent relay and queried in central Prometheus. Test scrape adapter is Go; packaged contrib agent container execution is NOT_RUN here |
| Rotation/re-enrollment, revoke A without affecting B | PASS | Actual registry policy updates and HTTP 401/200 outcomes; causal key remains stable |
| Disable and central disabled acknowledgement | PASS | Queue rejects new batches; registry receives explicit disabled state |
| Clone reset and missing identity | PASS | New ID/keys/credential state, synthetic product account retained; rerun migration does not regenerate deleted identity |
| Tempo `/ready` | FAIL/BLOCKED | Continuous ingester minimum-ready wait on this Colima host, including the explicit single-node diagnostic configuration. Successful storage queries are recorded separately |
| Full local fixture | BLOCKED | Never promoted to PASS despite functional tests succeeding; owned cleanup PASS |

The initial integration attempt exposed an implementation error: valid OTLP
responses containing an empty `partial_success` message were classified as
failure. The gateway now decodes the upstream response and distinguishes zero
rejections from actual partial loss; the regression test and real writes passed.

## Code, contract and UI verification

- Go focused installation/projection/gateway/export/relay/provider suites with
  race detector: PASS. `go vet ./...` and `go build ./...`: PASS.
- Full local Go test attempt: FAIL in `internal/load/exercise_actor` and
  `internal/load/run_profile` transport/503 fixtures. The same cases fail on an
  untouched archive of base `07a73cec`; this is retained as a local baseline
  limitation, not reported as a successful full run.
- OpenAPI parity and contract verifier: PASS, 116 public operations / four private
  exclusions. Traceability verifier: PASS for 39 committed requirements; the
  approved Windows brief is unavailable on this host.
- Web local-feature unit/build and all selected browser stages: PASS. The two
  broad real-stack app runs stop at the existing Tempo readiness preflight and
  remain FAIL/BLOCKED. Their report is not converted into PASS.
- Focused Web telemetry/settings: 24 PASS. New consent/layout browser cases:
  3 PASS (320/393/1440). Source-resolution 320 and 1440 captures inspected: full
  installation ID is readable, consent and status text wrap, buttons remain
  reachable through ordinary page scroll, no horizontal clipping.
- Flutter telemetry tests: 10 PASS, one pre-existing skip; this is not a no-skip
  native acceptance result. Targeted analyzer is run separately. Full native
  Android/iOS API runtime remains NOT_RUN at this checkpoint because the same
  owned stack preflight is blocked. No physical/mobile/media PASS is inferred.
- Fleet dashboard generation/scoping and backend profile receipt tests: PASS.
  The existing database CI profile also requires the owned two-installation
  runner; its successful source-bound receipt cannot omit that runtime check.

## Remaining operational verification

Production deployment/enrollment, real operator credentials/datasource setup,
packaged contrib-agent execution, physical Android/iOS queue behaviour and full
Grafana interaction are NOT_RUN here. Existing local/legacy dashboards remain
separate; no historical backfill or global end-user access is introduced.
The feature includes no statement about media FPS/capacity or audible playback.

Operator procedure: `docs/runbooks/installation-telemetry.md`.
Decision/privacy boundaries: `docs/adr/ADR-028-installation-telemetry.md`.
