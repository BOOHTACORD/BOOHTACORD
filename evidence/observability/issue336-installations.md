# #336 — installation-scoped telemetry

Date: 2026-10-21. Leaf: IT-001, dependency T-052.
Implementation base: `07a73cec706c5e54b88fea17bdfb6e5a02f46a16`.
Status at the final local checkpoint: full two-installation acceptance PASS,
including actual readiness and cleanup. Earlier BLOCKED attempts are retained
below. Linux CI acceptance is also recorded; final exact-head CI remains required
before merge.
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
Earlier diagnostic runs retained readiness as FAIL/BLOCKED. The final normal
run, with localhost excluded from the macOS system proxy, passes readiness and
both acceptance tests (44.289s), including production delivery-health SDK metrics
queried in real Prometheus. It tested the final working tree based on `9b63d675`;
CI provides the subsequent committed-source verification.
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
| Tempo `/ready` | PASS final / earlier BLOCKED | The final normal run bypassed the host system proxy for loopback only; no health gate or TLS check was bypassed |
| Full local fixture | PASS final | Both actual tests PASS, normal readiness PASS, owned cleanup PASS. Earlier diagnostic BLOCKED receipts/logs are distinct attempts |

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
  native acceptance result. Targeted analyzer: PASS, no issues. Full native
  Android/iOS API runtime remains NOT_RUN at this checkpoint in this issue; the earlier broad
  owned-stack app preflight failure is retained as a separate attempt. No physical/mobile/media PASS is inferred.
- Fleet dashboard generation/scoping and backend profile receipt tests: PASS.
  The existing database CI profile also requires the owned two-installation
  runner; its successful source-bound receipt cannot omit that runtime check.

## Additional verification

The full 1198-test Python suite passes with loopback excluded from the host's
system HTTP proxy (`NO_PROXY=127.0.0.1,localhost`); the original local attempt's
nine loopback HTTP errors remain in its ignored log. The egress checker now
requires shared Compose to have no deployment-specific host overrides, while
retaining its explicit OTLP configuration and outbound-network checks. Native
Compose image verification PASS using the installed standalone Compose CLI.
Delivery loss/queue/build instruments have focused SDK collection and strict
version-label tests; versions accept only bounded numeric semantic versions or
`unknown`, with per-installation cardinality enforcement unchanged. Fleet account
panels deduplicate process replicas rather than summing the same database gauge.

## Linux CI checkpoint

PR #512, source `773022c92ddbba47990a1897b14b6a6520971bf0`,
[run 39663120180](https://github.com/Egkurilov/BOOHTACORD/actions/runs/39663120180):
backend database profile PASS, including ordinary uncached Go/no-skip tests and
both actual two-installation acceptance tests (32.949s). The runner used its
normal readiness gate, with no diagnostic override. This establishes a complete
functional Linux fixture PASS independently of the retained Colima BLOCKED result.
Backend static/load also PASS. This intermediate run was not globally green:
contract Python checks exposed the new supplemental operation missing from the
sequential-shadow parity declarations and the intentional Compose change lacking
a source-only network evidence supplement. Two browser profiles needed alerts
scoped to the guild form now that the telemetry form has its own alert. These are
corrected and require a fresh exact-head CI run; no gate is removed or relaxed.
Focused corrected Python suites: 29 PASS. Browser guild lifecycle: 6 PASS;
control consistency behaviour: 2 PASS.

## Final dimension review

Focused regressions exposed and fixed two SFU issues before merge: the optional
agent's Prometheus filter must preserve histogram bucket/sum/count samples, and
projection must retain the reviewed finite `incoming`/`outgoing`, transmission,
source/type dimensions. The same review preserves bounded API route templates,
incident/pool statistics and media stage/role dimensions. Private node/user IDs
remain stripped. Conflicting series produced by dropping an unapproved dimension
are rejected rather than silently emitted with the same timestamp and labels.
These corrections have RED→GREEN regression tests. The normal owned fixture
passes again (44.475s), including two simultaneous API route series per process
with identical timestamps; readiness and cleanup PASS. This final local working
tree is based on `9a9dadf7`; exact committed-source CI remains required.

The latest broad local-feature Web attempt again passes all unit/build/browser
stages. Its app runtime stages now reach Docker build and fail because this host's
Docker CLI lacks BuildKit support for the existing Dockerfile `--mount`; no app
runtime PASS is claimed from that run. The independent #336 fixture does not need
an API image build and its actual storage acceptance remains separately recorded.

## Remaining operational verification

Production deployment/enrollment, real operator credentials/datasource setup,
packaged contrib-agent execution, physical Android/iOS queue behaviour and full
Grafana interaction are NOT_RUN here. Existing local/legacy dashboards remain
separate; no historical backfill or global end-user access is introduced.
The feature includes no statement about media FPS/capacity or audible playback.

Operator procedure: `docs/runbooks/installation-telemetry.md`.
Decision/privacy boundaries: `docs/adr/ADR-028-installation-telemetry.md`.
