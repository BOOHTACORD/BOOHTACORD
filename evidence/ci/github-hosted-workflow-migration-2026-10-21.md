# GitHub-hosted workflow migration — 21 October 2026

This records the source migration for CICD-12. Every executable job in the
repository's GitHub Actions workflows now selects an approved GitHub-hosted
image: Linux jobs use `ubuntu-24.04`, Windows jobs use `windows-2022`, and
macOS jobs use the explicit hosted labels declared by their workflow matrices.
The trust policy rejects other labels and unapproved runner expressions. The
old Hetzner runner documentation is now historical; this change does not stop
services or unregister runners on that host.

## Local validation

- **PASS** — 90 focused tests covering action trust, workflow routing, CI gates,
  toolchains, runner detection, and release/operator workflow contracts.
- **PASS** — `python3 -m tools.verify.action_pins.run` (36 workflows, 2 local
  actions).
- **PASS** — `python3 -m tools.verify.workflows.delivery`.
- **PASS** — `tools/verify/github_workflows/verify-github-workflows.ps1` and its
  workflow, native, migration, and observability checks.
- **PASS** — `tools/verify/spec_traceability/verify-spec-traceability.ps1`
  against the committed 39-requirement index. The approved source brief is not
  available on this host.
- **PASS** — `git diff --check`.

## External acceptance

- **PARTIAL** — The initial [PR #506 CI run](https://github.com/Egkurilov/BOOHTACORD/actions/runs/39618968735)
  used the `ubuntu-24.04` hosted image. Its contracts job found that the
  simulated hosted environment in an operator test omitted `RUNNER_OS`; the
  fixture now supplies `Linux` so the test reaches its intended SSH-timeout
  assertion.
- **NOT_RUN** — Fresh hosted checks after that fixture correction are pending.
  The initial red result remains recorded and is not relabeled as a pass.
- **NOT_RUN** — Production SSH connectivity from a GitHub-hosted runner. The
  production environment, source/provenance guards, protected approval, and
  serialized writer remain in place; no production workflow was dispatched.
- **NOT_RUN** — Retirement of the former self-hosted infrastructure. Inventory
  current host/service use separately before stopping or unregistering runners.
