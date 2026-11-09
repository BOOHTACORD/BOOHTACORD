# Issue 689: installation telemetry integration

- PASS: `python -m tools.qa.installation_telemetry.run` used disposable local
  PostgreSQL, Tempo, Collector, Prometheus and synthetic LiveKit instances.
  Both project acceptance tests passed, readiness passed and owned cleanup
  passed. The receipt and logs remain in the task-owned Linux snapshot.
- The Linux snapshot was based on `72928320d` and overlaid with the then-dirty
  source; changed and untracked file bytes were verified before the run. The
  runner's receipt records HEAD but does not encode the dirty overlay, so it is
  not an immutable candidate receipt. The first attempt did not start because
  the prior temporary snapshot had disappeared; the successful run used a
  newly created persistent task-owned snapshot.
- This proves the existing two-installation telemetry integration only. It
  does not prove end-to-end export of every new roster/maintenance metric or
  production dashboard and alert equivalence.
