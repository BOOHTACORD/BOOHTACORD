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
- **PASS** — 15 Flutter shadow-control tests after updating the legacy runner
  expectation to GitHub-hosted defaults.
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

- **PASS** — [PR #506 CI](https://github.com/BOOHTACORD/BOOHTACORD/actions/runs/39620521386)
  passed all 26 jobs on commit `6e6f699ba4d42993704c744cf64a76223e1cd12f`.
  The hosted contract suite, Linux, Windows, Flutter, browser, backend, and
  runtime jobs all completed successfully.
- **PASS** — [GitHub-hosted runner proof](https://github.com/BOOHTACORD/BOOHTACORD/actions/runs/39620511796),
  [dependency cache acceptance](https://github.com/BOOHTACORD/BOOHTACORD/actions/runs/39620521391),
  and [trusted-delivery acceptance](https://github.com/BOOHTACORD/BOOHTACORD/actions/runs/39620521428)
  passed on the same commit.
- **RESOLVED** — Earlier CI runs exposed two stale test fixtures: the operator
  hosted environment omitted `RUNNER_OS`, and a Flutter legacy test expected
  self-hosted-only concurrency. Both were corrected before the successful run.
- **NOT_RUN** — Production SSH connectivity from a GitHub-hosted runner. The
  production environment, source/provenance guards, protected approval, and
  serialized writer remain in place; no production workflow was dispatched.
- **NOT_RUN** — Retirement of the former self-hosted infrastructure. Inventory
  current host/service use separately before stopping or unregistering runners.
