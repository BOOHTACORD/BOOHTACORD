# Codex CI readiness before each commit

Read `AGENTS.md` first. This playbook complements the existing CI; it is not a
replacement for CI, native tests, real-stack acceptance, or source-bound receipts.
The `contracts` PR job runs independently of the `changes` job. Routing comes
from `tools/ci/select_changes/dependencies.json`, not a second gate map.

Copy this prompt into a Codex task when useful:

```text
Before starting, read AGENTS.md and docs/development/codex-ci-readiness.md.
Before every commit, run python -m tools.ci.preflight.run --base <target-ref>.
Inventory staged, unstaged, untracked and merge-base diff, including renamed and
deleted paths. Review the whole intended change and related contracts, consumers,
fixtures, requirements, backlog, generated outputs, dependency locks, migrations,
deployment, feature registry, tests and applicable evidence. Run applicable
native checks below, and inspect untracked file whitespace and file contents too.
Repeat status and diff after tests, before staging and before committing. Report:
base and merge-base; changed files and unexpected files; selected gates;
companions; Contracts / Traceability / Evidence / Generated / Dependencies /
Client checks as PASS, FAIL, N/A or BLOCKED, with exact commands and reasons;
and COMMIT_ALLOWED or COMMIT_BLOCKED. Use N/A only after explaining why.
FAIL, missing companions, stale output or unexplained BLOCKED blocks commit;
NOT_RUN or BLOCKED never closes a required gate. Never weaken tests, CI,
snapshots or source SHA for a green result. Never commit secrets, runtime
artifacts or unrelated generated data. Do not stage the root blindly.
```

Use `--json` for machine-readable inventory. The command is intentionally
conservative: without a review it exits nonzero and reports `COMMIT_BLOCKED`
because it cannot prove semantic review or heavyweight checks. After completing
those checks, provide the explicit manual review described below. Its decision
is an attestation, not proof that this program executed those commands. An unknown selector path
sets `uncertain` and expands gates; investigate rather than narrowing them.
It also reports the existing actual-acceptance selector and runs the product-map
and flow-contract generator checks with bounded timeouts. A missing tool or
dependency is BLOCKED; a successful generator check does not prove other checks.
For a `contracts/**` diff it also runs the contract verifier; for a `backlog/**`
diff it runs traceability when the approved brief is available. These conditional
checks time out after 45 seconds and missing tools or the approved brief are
BLOCKED. On non-Windows hosts set `VOICE_PLATFORM_APPROVED_SPEC_PATH` to the
available approved brief before checking backlog changes.
For client source or registry changes, preflight also reuses the registry's
parity validator and checks changed registered features against the merge-base
decision. An invalid registry or unchanged required decision blocks commit.
Unmapped client paths remain BLOCKED until the agent explains their semantics;
an unrelated source change need not be treated as a UI behavior change.
The inventory includes both sides of renames and does not read ignored runtime
files. Untracked files get a separate `git diff --no-index --check`; inspect
their contents as well.
Web dependency declaration changes without a lockfile diff require explicit
review; a compatible existing lock can be a valid exception. Check staged and
unstaged versions independently when they differ.

### Explicit review input

After running the checks, save a JSON review outside the intended diff and run
`python -m tools.ci.preflight.run --base <target-ref> --review <review.json>`.
Copy the `fingerprint` from the latest JSON output. The review must contain a
`checks` object with all six category names shown in the prompt, each with
`status` (`PASS` or `N/A`) and a nonempty `reason`; every PASS also needs the
exact `command`. `Contracts` must be PASS. Add `gate:<name>` with PASS, command
and reason for each selected CI gate except `server` (which is release impact),
and `actual:<profile>` for each selected actual profile. Do not attest a gate
that was not run. A selected hosted CI job that cannot run until a PR exists may
be reported as `BLOCKED` with `scope: "hosted_ci"`, its exact job name in
`command`, and the reason; it remains an open required gate even if the local
commit is allowed. Failed or unexplained checks never become pending CI.
If staged and unstaged/untracked files coexist, add a `Staging` PASS with the
review commands and explain why the staged snapshot includes all required
companions. Native verifiers run against the working tree, not a reconstructed
index; inspect the staged version independently.
For a valid dependency-lock exception use Dependencies PASS
with the checking command and explanation. An example **shape**, with values
omitted deliberately, is:

```json
{"fingerprint":"<from-preflight>","checks":{"Contracts":{"status":"PASS","command":"<executed command>","reason":"<observed result>"},"Evidence":{"status":"N/A","reason":"<applicability decision>"}}}
```

This example is incomplete and will be blocked. The program blocks a stale
fingerprint, missing or failed review, missing selected gate, failed fast check,
unavailable generator, sensitive path, or a change observed during checking.
It reports the submitted statements as manual attestations. Re-run immediately
before commit; a later edit invalidates the fingerprint. A commit cannot close
a CI or physical gate that has not actually run.

## Change-to-obligation matrix

| Change or meaning | Review companions and run |
| --- | --- |
| Any PR | Contracts is mandatory. Where the environment permits: `python -m tools.ci.native.contracts`. Also inspect the full reusable `.github/workflows/ci-contracts.yaml`, which runs checks beyond that native runner. |
| Contract semantics, schema or fixtures | Consumers, tests and fixtures; `pwsh -NoProfile -File tools/verify/contracts/verify-contracts.ps1`. |
| Approved requirements or backlog | Traceability and test evidence; `pwsh -NoProfile -File tools/verify/spec_traceability/verify-spec-traceability.ps1`. |
| Product-map-sensitive sources or catalog | `python -m tools.product_map validate-parity` and `python -m tools.product_map generate --check`; see the CI workflow for transition/ownership checks. |
| Flow or observability sources and contracts | `node tools/observability/flow_contract/generate.mjs --check`; `python -m tools.observability.signal_catalog.build --check` when its inputs change. |
| Web dependency declarations | Review `clients/web/package-lock.json`; `npm ci --prefix clients/web --ignore-scripts`. |
| Dart dependency graph | Review pubspec and lock; `python -m tools.verify.dependencies.dart`. |
| Web, Android or iOS behavior/UI | Update `tools/qa/local_features/features.json` and focused tests; run `./tools/qa/local_features/check.sh --feature <feature> --base <base-ref> --real-stack` with applicable native target, inspect screenshots at source resolution and record observations. Missing devices are BLOCKED, not PASS. |
| Compose or deployment | Migrations, configuration, rollout compatibility and `docker compose --env-file .env.example -f deploy/compose.yaml config --quiet`. |
| POC, integration, load or release gate | Review the applicable source-bound `evidence/` record. Do not assume every UI or code diff requires a new record. |

Regenerate drift with the owning generator and review its diff. Do not rewrite
expected values, verifier or source identity merely to obtain PASS. The command
`python -m tools.ci.receipts.run contracts` requires the CI-like clean checkout
and source identity; it is not an unconditional dirty-worktree substitute for
the native runner. Runtime `.out/**` and Actions profile uploads are transient;
they must not be committed to satisfy evidence requirements.

## Failure triage

Inspect the earliest failed step before a later upload or aggregate failure.
In Actions runs 43377894221, 43376345636 and 43375837052, the Python suite's
`tools.observability.signal_catalog.test_build` failed on stale checked-in
inventory. The Caddy test was skipped; its unconditional upload then failed
because `.out/ci/upload-proxy/` did not exist. If the test actually starts,
its wrapper creates a FAIL summary before checking environment and preserves a
failed result. An attempted upload-condition change also changed a workflow
hash checked by LiveKit historical evidence; fixing that diagnostic path needs
a separately reviewed source revalidation, not a rewritten historical PASS.
The primary failure was reproduced on merge commit
`ea8ac3ac3926ff8f257ef294271500f6bce80213` with
`python -m unittest tools.observability.signal_catalog.test_build.SignalCatalogTest.test_checked_in_inventory_matches_current_sources`:
the checked-in catalog differed from the rebuilt source inventory. The Caddy
wrapper itself was not executed in that run, so this reproduction does not claim
a Caddy test failure or fix.

In run 43394550505, browser-voice failed a settings hierarchy assertion because
the alert locator matched two elements; the Web aggregate then rejected profile
evidence. `tools.ci.web_suites.run` produces runtime profile JSON and the fan-in
checks source, reviewed plan, operations, run/attempt identity and job success.
Inspect the producing job and its artifact, not a fabricated `evidence/*.json`.
Runtime/browser acceptance, actual lifecycle and infrastructure failures need
their own diagnosis. Cancellation can be supersession by `cancel-in-progress`;
do not call it a test FAIL without evidence.
