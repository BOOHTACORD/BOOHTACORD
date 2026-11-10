# Issue 689: WebSocket roster observability

- PASS: the new roster subscriber, initial-frame outcome, delivery outcome and
  duration, coordinator refresh outcome, last-success time and observation marker
  are wired to production lifecycle owners. Metric labels use bounded outcomes;
  they do not include account, session, channel or message data.
- PASS: the SDK emits these instruments, the central projection preserves only
  approved names and bounded outcomes, and the owned two-installation telemetry
  fixture delivered actual SDK data through its signed gateway and Collector to
  real Prometheus. Three integration tests passed; fixture readiness and cleanup
  both passed. This run preceded removal of the old counters; the actual source
  was dirty at HEAD `72928320d`.
- PASS: a separate local two-account, one-room real-stack smoke observed two WS
  roster subscribers, two successful initial frames and successful refreshes in
  the API Prometheus scrape. Report:
  `.out/roster-matrix/candidate-2-1-change-20261109T073236Z-7328e4d2/`.
- PASS: Prometheus v3.11.2 promtool accepted all 17 local and fleet dashboard expressions and
  four alert rules, plus six synthetic scenarios for idle, initial failure,
  initial unavailable, refresh blackout, delivery blackout and missing metrics.
  Dashboard contract tests include the fleet dashboard.
- After equivalent signals and central storage were tested, retired SSE-only
  instruments and the unused SSE-specific stages were removed. Shared LiveKit
  dependency metrics remain under `roster_dependency_metrics`.
- PASS: full Windows Go 1.26.4 backend suite against owned PostgreSQL 17.6:
  1853 tests/subtests passed, zero failed or skipped; `go vet ./...` and
  `go build ./...` passed, and the owned database fixture was removed.
- NOT_RUN: production dashboard import, production scrape, alert delivery and
  on-call response. The local evidence does not establish deploy readiness.
- PASS again after retired instruments and labels were removed: all three
  installation-acceptance tests, including real SDK-to-Collector-to-Prometheus
  roster WS export, completed with fixture readiness and cleanup PASS. Source
  was still dirty, so this is not immutable-release evidence.
