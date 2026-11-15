# Issue 789: readiness work in progress

Base: `11eb58b4fb312e9b50e1ad8a8edfcd8dcc5a7870` (origin/master at intake).
This record does not close the issue or attest a PR, release or CI gate.

- PASS: focused preflight, existing selectors and upload-proxy tests: 64 tests
  using `python -m unittest tools.ci.actual_acceptance.test_plan tools.ci.select_changes.test_selection tools.ci.select_changes.test_routing tools.ci.select_changes.test_diff tools.ci.preflight.test_inventory tools.ci.preflight.test_report tools.ci.preflight.test_dependencies tools.ci.preflight.test_generated tools.ci.preflight.test_review tools.ci.preflight.test_client_registry tools.ci.preflight.test_related_checks tools.qa.upload_proxy.test_ci` on Windows. The suite includes real temporary missing-fixture, traceability-drift and stale-flow cases.
- PASS: 27 focused preflight and upload-proxy tests under Ubuntu WSL. Python 3.14.4
  there does not match the Linux CI Python version.
- PASS: `pwsh -NoProfile -File tools/verify/contracts/verify-contracts.ps1`;
  `pwsh -NoProfile -File tools/verify/github_workflows/verify-github-workflows.ps1`;
  `python -m tools.verify.links.check`.
- PASS: `python -m tools.product_map generate --check`,
  `node tools/observability/flow_contract/generate.mjs --check`, and
  `python -m tools.observability.signal_catalog.build --check`.
- PARTIAL: `python -m tools.product_map validate-parity` reports its parity
  projection passed but explicitly says full product-map validation is not implemented.
- FAIL: `python -m tools.ci.native.contracts` on Windows stopped at the shared
  Python test suite. Observed errors include missing `cmake` and bash receiving
  Windows-style temporary paths; other failures require individual triage.
- NOT_RUN to completion: the same native runner under Ubuntu WSL was interrupted
  after prolonged I/O wait on the Windows-mounted worktree. Its partial output
  is not a passing result; the environment also lacks native Node and pinned Python.
- PASS: `python -m tools.ci.native.contracts` in an isolated Linux checkout with
  byte-matched implementation, Python 3.12.15, pinned Python dependencies and Node
  24.18.0. The Python suite ran 1773 tests with 27 skips; subsequent native
  checks completed successfully. Linux Go 1.26.8 and Compose 2.40.3 differed
  from project pins, so this is not an exact hosted CI reproduction. The
  traceability verifier reported that the approved brief was unavailable and
  validated only the committed requirement index.
- PASS: `pwsh -NoProfile -File tools/verify/spec_traceability/verify-spec-traceability.ps1`
  on Windows checked the approved brief's SHA-256 and all 39 requirement IDs.
- PASS: after syncing to master `9e7113fc68e0ce07018436f4112bb1027ede686a`,
  the same isolated Linux native contracts runner completed 1774 Python tests
  with 27 skips and its subsequent checks. Its Go/Compose and approved-brief
  limitations are unchanged.
- PASS: after restoring the original contracts workflow, 42 Linux tests covering
  earlier environment failures and LiveKit evidence verification passed. A
  workflow change had caused a historical artifact hash mismatch; the diagnostic
  change was removed instead of altering existing historical evidence.
- REPRODUCED FAIL: on historical merge commit
  `ea8ac3ac3926ff8f257ef294271500f6bce80213`,
  `python -m unittest tools.observability.signal_catalog.test_build.SignalCatalogTest.test_checked_in_inventory_matches_current_sources`
  failed because the rebuilt signal inventory differed from its checked-in
  output. The associated hosted Caddy step was skipped; its upload failure was
  secondary and does not prove a Caddy test failure.
- BLOCKED: final PR CI, ci-required, fail-fix-pass demonstration, all selected
  platform and runtime checks, and issue completion. No commit or PR is attested.

The local preflight reports COMMIT_BLOCKED until a human/agent has performed
semantic review and applicable checks. Its optional COMMIT_ALLOWED result is
based on explicit manual attestations bound to the current diff; it does not
independently execute the attested heavyweight commands.
