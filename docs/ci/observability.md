# CI failure triage and flake policy (#402)

`ci-required`, `server-quality` and `native-required` always publish a source-bound
job summary and finite sanitized triage JSON, including on failure. They show
source/run/attempt, selected components/gates, failing component and step number,
its source job link, owner/reproduction command, retry count and observed timing.
The source command needs the matching checkout, pinned SDKs and retained input
artifacts: a command in a summary does not reproduce a missing physical device.
No raw Actions logs, review payloads, actor names, usernames, sessions or artifact
contents are collected. Unknown root causes remain UNVERIFIED.

The prior gate validator still decides required quality. Diagnosis does not hide
its failure. Missing/stale metadata, failed evidence or conditional/soft-failed
triage retention is red. Summaries use `always()`, upload one exact JSON, require
its presence and retain it 30 days with source/run/attempt naming. No required job
uses `continue-on-error`. The only added permission is read-only Actions metadata
on those aggregate jobs; no production environment, signing/SSH key, write scope
or inherited secret is introduced. Actual required repository settings remain an
owner-controlled readback item (#385); this implementation names the three stable
repository aggregates rather than claiming to know uninspected protection rules.

## Source identity

Current gate diagnostics verify the checkout and API run/attempt identity. A PR
API head may be the branch commit rather than the tested synthetic merge: the
helper accepts that distinction only when the checked merge's second parent is
exactly that head and GitHub identifies the PR merge ref. It records both SHAs
and the binding. Master/native scopes require their own workflow identity.
The manual `Read-only CI triage` dispatch takes an exact run ID/API head SHA and
labels it `api_head_only`; it never claims a verified historical tested merge.
A cancelled PR/dependency remains cancelled/red and is not claimed as evidence
of a master defect. A rerun is not proof of a flaky assertion.

## Reproduce the historical report

```sh
python -m tools.ci.observability.report \
  --cache .out/issue383/metadata \
  --frozen evidence/ci/baseline-2026-10-18 \
  --output .out/ci-triage.json
```

The collector reuses all **40 completed** sanitized original #383 records,
checks them against the frozen sample identities and records every input hash.
It performs no live test/release, log download or production access. The committed
analysis is `evidence/ci/ci-triage-2026-10-19.json`; source URLs identify every run
and recurring failure. The local cache is not committed. If unavailable, obtain
a fresh bounded metadata collection using the existing #383 collector and keep
its sample window separate; do not invent missing steps from compact summaries.

| Historical cohort | Completed runs | Successful workflow wall p50 / p95, sec | First-start delay p95, sec |
| --- | ---: | ---: | ---: |
| CI PR | 15 | 1548 / 1601 | 100 |
| Former CI master | 15 | 1533 / 1625 | 5 |
| Server build | 3 | 1209 / 1284 | 3 |
| Deploy workflow | 3 | 98 / 695 | 5 |
| Windows release | 2 | 962 / 962 (one success) | 494 |
| Android release | 2 | unknown (no successful sample) | 3 |

The 40 records include 5 failures and 6 cancellations. Two Windows GUI/SFU
failures recur, two Android signing/build failures recur and one Windows
analysis/test failure is separate. Those are **recurring failures**, with unknown
root cause, not confirmed flakes. Windows release rerun rate is 1/2; other sampled
cohorts have zero observed reruns. Confirmed flake rate is unknown, not zero.
Ownership: Windows/Media, Native/CI and CI/Artifacts as indicated by each record.

These are before-migration observations, not measured improvements. Successful
workflow wall time is a proxy for PR-to-green; owner status settings are unknown.
Created/start delay can include dependencies, dispatch and approvals, so pure
queue time stays null. Runner execution minutes sum job occupancy across all
attempts without billing multipliers/rounding. Deploy completion is not an exact
master-to-healthy or source-provenance attestation. Current live aggregate timing
is partial while its own job runs and is labelled completed-job execution only.

## Retry and flake handling

`policy-v1.json` permits **two** attempts only for authenticated read-only Actions
metadata GET transport: HTTP 500/502/503/504, timeout or connection reset. Identity,
auth 401/403, missing evidence 404, malformed JSON, wrong source and assertions do
not retry. Redirects are refused and data is bounded. Fault-injection tests prove
the allowed transient and exhausted cases. No test, auth/ACL, signing, deployment
health or runtime acceptance command is rerun by this policy. Existing immutable
release upload recovery remains governed by its separate verified-byte contract.

No tests are quarantined or automatically ignored. To investigate a suspected
flake, preserve failed/successful run IDs, exact tested source and command/profile,
SDK/runner inputs and sanitized evidence; assign the component owner and record
root-cause/reproduction evidence. Same API head or a later green run is
insufficient, especially for a changed PR merge base. Until proven, leave the
original gate red. Fix the cause through a reviewed change rather than rerunning
tests until green. No new automatic test retry exception is authorized here.

## Alert and operator criteria

The versioned triage thresholds are signals, not production capacity/SLO claims:

- successful workflow wall p95 above 1200s or first-start delay p95 above 300s:
  inspect source-matched cohort, dependency/approval waits and native profile cost;
- two recurring failed gate fingerprints: component owner reviews the same
  source/step evidence; do not label it flaky without proof;
- queued/waiting workflow or required status above 900s: inspect selected DAG,
  approvals, runner allocation and cancellation before retrying;
- self-hosted waiting job above 600s: CI/Operations checks runner availability
  and pending environment approval; metadata alone does not prove it is offline;
- failed/missing evidence retention: CI/Artifacts restores the mandatory artifact
  path and source/attempt binding; an old or empty artifact is not a replacement.

Manual triage supports incomplete/waiting runs and emits these signals with
UNVERIFIED causes. No external notifications or automatic mutating repair are
sent. Missing authenticated metadata is BLOCKED, not a successful quality result.
Workflow contracts, source/privacy and fault tests run in the mandatory contracts
gate; actionlint and the existing graph/trigger/permission verifiers remain active.
New live summary integration and after-migration flake/performance observations
remain NOT_RUN pending the combined acceptance campaign.
