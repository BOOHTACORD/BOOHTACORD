# Stable required gate (CICD-03, #385)

Workflow `CI` publishes the stable check name **`ci-required`**. It always waits for
change selection, contracts, backend, frontend, Flutter and Windows, then validates
actual `needs` results. All currently applicable heavy/native/real acceptance gates
remain mandatory; this does not move them to advisory or make CI faster by skipping
required work.

| Evidence | Allowed result |
| --- | --- |
| Selector | success, complete outputs, current map version/digest |
| Contracts | success; selected unconditionally |
| Selected backend/Web/Flutter/Windows | success |
| Unselected component | skipped |
| Failed, cancelled, missing or unexpectedly skipped dependency | FAIL |
| Uncertain selector with any component unselected | FAIL |
| Missing/malformed/stale selection or role mapping | FAIL |

`if: always()` prevents an upstream failure from silently skipping the aggregate.
Concurrency cancellation can cancel the whole workflow, including the aggregate;
that is a non-green check and must block a protected merge. Needs are passed in an
environment JSON value, not interpolated as shell source. Raw needs/event values
are not logged. The aggregate runs on a hosted runner with the workflow's read-only
permissions and no signing/deploy credentials. Fork PRs use the same read-only graph.
`merge_group: checks_requested` is supported conservatively if merge queue is later
enabled: the unknown merge-group diff selects all gates. Dispatch does the same.
No branch/tag/environment protection settings are silently changed.

```sh
python3 -m unittest tools.ci.required_gate.test_validation tools.ci.required_gate.test_run tools.verify.workflows.test_selection
python3 -m tools.verify.workflows.selection
```

The workflow policy verifier derives semantic roles from reusable workflow edges.
Renaming a component job requires updating the aggregate needs/explicit role map.
Neither display names nor optional jobs may conceal a mandatory dependency.

## Real scheduler proof, isolated from product acceptance

`tools/ci/required_gate/proof.yaml` is an inactive fixture. Copy it to
`.github/workflows/ci-required-proof.yaml` in a **throwaway unmerged PR** to exercise
actual GitHub Actions job result/skip semantics. It invokes the exact production
aggregate module and dependency map, with a controlled backend fixture job and
expected irrelevant component skips. It does not run/prove backend, native, media,
or UI product tests. Set `PROOF_FAILURE: 'true'` to observe a real failed child and
red `ci-required`; then set it to `'false'` and observe green. No `continue-on-error`
is used on either the child or aggregate. Remove/close the throwaway branch after
retaining run links. For this scheduler-only fixture, the throwaway PR can disable
the ordinary `CI` pull_request trigger, so native gates are not needlessly built;
that trigger change must never be merged.

## Separate administrator step — required before #385 can close

Issue #385 explicitly requires separate administrator confirmation of repository
settings. Code rollout alone cannot establish a protected merge policy. Until that
confirmation and a readback exist, the settings criterion remains **BLOCKED**.

Proposed owner action after reviewing the rollout:

1. In repository Settings → Rules → Rulesets (or Branches → protection), target
   `master` and require the **`ci-required`** status from GitHub Actions.
2. Keep existing protection/review/environment/tag policies; do not remove another
   required status until its coverage and migration are agreed. Require a green
   latest head/merge-queue run, with missing/red/cancelled aggregate blocking merge.
3. Confirm the applied rule name, required status and merge behavior in #385.
   Record actual settings/readback, including any administrator bypass policy;
   do not infer settings from a green check or from inability to read admin APIs.
4. Revert only the new requirement if a rollout issue blocks all merges, keeping
   existing policies and restoring the last reviewed workflow version through PR.

The parent epic #382 stays open until its remaining delivery/native/physical and
cutover gates have their own evidence. This change cannot close them.
