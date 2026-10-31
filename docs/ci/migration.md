# CI/CD migration, cutover and rollback (#401 / epic #382)

Implementation and acceptance are separate. Changes have been delivered in
reviewable increments; a merged workflow is not proof of a successful native,
production or physical run. The current migration decision is **NO-GO** pending
combined actual acceptance and owner settings/review. Expensive runs were deferred
while implementing the remaining leaves, as requested by the owner.

## Canonical issue map and delivery phases

GitHub leaf titles are authoritative for CICD IDs: #386 is security/CICD-12,
#387 is artifacts/CICD-18, #388 is Web/CICD-04. The state collection in
`evidence/ci/migration-issues-2026-10-19.json` records 20 leaves, with 7 closed and
13 open at collection. Closed issue state alone is not an acceptance receipt.
Dependency IDs have been corrected against this collection.

| Phase | Leaves | Required result before cutover |
| --- | --- | --- |
| A: baseline and safety | #383/C01, #384/C02, #385/C03, #386/C12, #392/C08 | Reproducible baseline, conservative routes, negative security/provenance tests; owner verifies required statuses |
| B: parallel suites | #388/C04, #389/C05, #390/C06, #391/C07, #398/C15 | Same-source old/new suite comparison, coverage preserved, actual docs/backend/web/flutter/windows/contracts/shared/unknown PR matrix |
| C: trusted delivery | #393/C09, #394/C10, #395/C11, #396/C13, #397/C14, #399/C16, #400/C17, #387/C18 | Exact source/attempt receipts; private cache evidence; signed immutable bundle; trusted install/readback and compatible rollback; platform candidates; separate operator/SDK boundaries |
| D: cutover | #401/C19 plus owner #385 | Current workflow/trigger/permission/graph checks, tested configuration rollback candidate and owner protection readback |
| E: observation | #402/C20, #401/C19 | 30+ qualified after observations, comparison limits, release verification, known risks and authenticated independent owner GO |

Every issue is linked at `https://github.com/BOOHTACORD/BOOHTACORD/issues/<number>`.
Its implementation/evidence updates link the corresponding PRs. Recent code
increments are #437/#439/#440/#441/#443/#444/#445/#446/#447/#449; the issue registry
is a state collection, not a replacement for their immutable evidence.

## Required statuses and source ownership

`ci-required` is the stable PR/merge-queue aggregate. Contracts always run;
applicable backend/Web/Flutter/Windows and actual profiles follow the common
versioned selector. Unknown changes select conservatively; selected failures,
cancellation, missing/stale artifacts and unexpected skips cannot become green.
Master server quality belongs to `Build server` once, with exact-source receipts;
`Native master quality` remains independent. Successful `CI` on master is not a
replacement for those producers. Production consumes only authenticated complete
signed source-bound artifacts and fresh readback.

The owner applies/reads back repository required checks (#385), protected
environments and runner/account boundaries (#386/#399). No automation in this
change changes branch protection, self-approves a deployment or mutates a
production host. PR/fork diagnostics are read-only. Existing signing/provenance,
health, ACL and actual acceptance assertions remain mandatory.

## Readiness report and owner decision

```sh
task ci:readiness
# Equivalent: python -m tools.ci.migration.readiness
```

The empty tracked `evidence/ci/cutover-acceptance-template.json` intentionally
produces NO-GO. The 16 versioned criteria are in
`tools/ci/migration/criteria-v1.json`. They cover baseline; the eight actual PR
controls; security/provenance negatives; same-source suite shadows; server
release/install/compatible rollback; Android/Windows/macOS smoke; installed Windows
promotion; operator restrictions; native SDK matrix; owner status readback;
configuration rollback and after observations.

An acceptance manifest lists **tracked canonical receipt paths**, not caller
PASS/GO booleans. A canonical JSON receipt has schema_version 1, criterion,
source_revision, expected scope, executed=true, status=PASS and nonempty evidence
references with exact SHA256 of other tracked records. Actual scope additionally
requires actual_runtime=true and mocks=false. Admin readback names `ci-required`
and confirms verified settings. Install/rollback, native processes, SDK matrix,
source/coverage shadows and negative-test criteria have their specific assertions.
The control matrix requires all eight actual workflow cases from the tested base;
metadata criteria require 30+ samples. After observations include finite p50/p95/n
for PR green, actual master healthy readback and runner occupancy. No unit fixture,
packaging-only run or NOT_RUN/BLOCKED report may be relabelled actual PASS.

Only reviewed evidence belongs in those canonical summaries: reference original
sanitized tool outputs, source/run/attempt and physical records where applicable.
Do not manufacture flags to satisfy a schema. References are limited to tracked
text under evidence/, verified byte-for-byte; no local arbitrary file, credential,
symlink, mutable URL or inline untracked PASS replaces a record. Current code must
match the tested candidate; only added/updated evidence files may differ. Changes
to product, CI, docs/requirements or backlog invalidate that equivalence and need
a new tested candidate.

The manual `Migration readiness and owner GO review` workflow first prepares and
retains a concrete mechanical report **without an environment approval**. Only
when all evidence qualifies and `request_go_review=true` does its independent
master-only review job enter the protected production environment. It then
revalidates evidence and authenticates the exact run/source/attempt/environment
review through GitHub, requiring a reviewer other than the triggering actor.
A caller's `verified=true` or `GO` JSON is insufficient. An approved review for
another source or a missing approval remains NO-GO. There are no write, SSH,
signing or repository-admin permissions in either job. GO is a reviewed decision;
it never deploys, changes protection or closes issues automatically.

## Configuration rollback: reviewed candidate, never production rollback

The initial approved rollback checkpoint is
`c569477fc0d125f3313e73742c34a2ea6aa5e454` (post-#400). It retains the hardened
source/signature contracts and stable ci-required envelope. This rollback targets
a later CI configuration/observation regression; it is **not** permission to revert
all modernization to an insecure historical DAG. Earlier checkpoints require a
new reviewed safety/compatibility decision.

```sh
task ci:workflow-rollback:preview
# Review .out/ci/migration/workflow-rollback.json and workflow-rollback.patch.
# From a clean owned QA checkout, create the exact candidate branch printed there:
git switch -c codex/workflow-rollback-<source-prefix>
python -m tools.ci.migration.rollback apply
# Run the fixed workflow validators and actionlint; commit/review a candidate PR.
```

Preview is read-only. Apply refuses master, unrelated branches, moved/dirty source,
wrong checkpoint, changed patch/hash or an expanded path set. It restores only
reviewed `.github`, `tools/ci`, CI graph/action-policy verifier paths and exact
Taskfile/toolchain config
paths. Product/backend/client/deploy/release implementation, database/volumes,
credentials, product-contract/QA verifiers, historical evidence, docs and backlog
stay outside this restore set.
The staged result must match the exact planned path set. No force push, automatic
commit/merge, rule change, signing, install, SSH or service operation occurs.
A candidate still needs the source-bound policy/graph/negative checks and owner
review; configuration rollback must not remove core gates just to get green.

Validate a candidate with reviewed action pins/trust, component selection,
delivery and native graph validators, actionlint and the focused native required
semantics. Original evidence remains available. Fix forward or restore the tested
configuration through an ordinary reviewed PR; do not mutate live rules while a
writer is in flight. The rollout and on-call instructions remain in
`docs/ci/operator-workflows.md`, `docs/ci/master-quality.md`,
`docs/ci/windows-promotion-trace.md` and the existing release runbooks.

Production rollback is a separate protected operation: retained signed releases,
identical backend/schema/topology, resource-identity checks, two observers and a
maintenance window, shared non-cancellable production and host lock, guarded
restoration and fresh readback. A failed/lost connection is NOT_VERIFIED, not an
automatic retry. Workflow rollback never creates backups, snapshots or pg_dump.

## Observation, risks and closure

The #383/#402 historical collection contains 40 complete source-linked runs.
Before-migration successful workflow wall p50/p95, start delays, runner occupancy
and recurrence are recorded. They are not exact required-green/healthy times or
confirmed flake frequency. Current after data and actual smoke are NOT_RUN; no
measured win is claimed. The absence of a native/physical runner or environment
approval is BLOCKED. Metadata, ad-hoc signatures and compiled frameworks do not
prove physical playback, capacity, Developer ID or notarization.

Close a leaf only with its own qualifying evidence. Finish the combined control
matrix, actual release/install/rollback/platform checks and 30+ after observations,
record the owner decision, then close #401 and the epic. A merged implementation,
a local contract PASS or this report's existence is insufficient. The decision
and remaining items are retained in `.out/ci/migration/readiness.json`; the checked
implementation/candidate evidence is in `evidence/ci/migration-readiness-2026-10-19.md`.
