# Windows promotion trace (#397)

Promotion still creates a review PR; it never writes master, merges, applies a
production rollout or drives an installed client. #249 retains the real
1.0.32 → 1.0.38 Windows installed-client acceptance. Repository required-status
settings remain owned by the administrator (#385).

## Source and permissions

The promotion workflow checks out its exact dispatched master SHA. Three
protected jobs separate permissions:

| Job | Token permissions | Operation |
| --- | --- | --- |
| push-candidate | contents:write, pull-requests:read | Verify immutable release, create/reuse only the exact data-only branch |
| candidate-ci | contents:read, actions:write | Dispatch and verify a new complete CI execution for that exact SHA |
| prepare-catalog-pr | contents:read, actions:read, pull-requests:write | Recheck catalog/branch/CI/assets and open or reuse the review PR |

A frozen `deploy/client-updates/promotions/<intent-sha256>.json` binds expected
and resulting catalog revision, before/after catalog hashes, exact
windows/direct/stable/x64 selector, target hash, source commit and release
manifest/archive/checksums/complete remote asset inventory hashes. No other
selector can change. Order must increase for a changed published target, and
version/native build cannot decrease. A classic ZIP promotion cannot remove an
existing signed install_artifact; that requires the separate signed-artifact
promotion path. This change adds no unsigned in-app trust metadata.

The current six-asset Windows release and its embedded SHA256SUMS are supported;
legacy two-checksum verification remains available to existing callers. The new
pipeline requires authenticated complete release metadata and an exact current
tag-to-manifest source binding. All native payload bytes are still verified
before any catalog branch. Rechecks bind the whole published asset set and tag,
not merely the release title or a mutable download URL.

Branch names are deterministic for identical inputs/source. Existing branches
must have exactly the intended parent and only the catalog/intent changes with
identical content. No force push occurs. Another open automated Windows
promotion conflicts before CI; repeated identical dispatch reuses its branch
and review PR, while retaining the original PR's candidate-CI link and the new
run's fresh evidence. Master catalog revision/hash is rechecked before creating
the PR. A race after that check is rejected when the actual PR/merge-queue CI
intent verifier re-evaluates the current base; the owner must enforce up-to-date
required checks/merge-queue policy (#385). It validates GitHub's test-merge catalog against the current
base, and rejects changed/deleted frozen intents. Ordinary non-promotion catalog
flows are not rewritten by this verifier.

## CI, review and merge

Dispatch snapshots existing matching run IDs before requesting CI; historical
PASS cannot satisfy the new dispatch. Branch and SHA are checked before dispatch,
and source/branch/workflow/repository/run/attempt plus successful ci-required are
verified before PR. Missing, cancelled, failed, skipped, foreign or rerun proofs
fail closed. The fresh proof is retained separately and its exact identity is
embedded in the review PR. Reuse also revalidates the original PR proof.

Current [GitHub trigger documentation](https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/trigger-a-workflow)
explains that GITHUB_TOKEN-created opened/synchronize/reopened PR events can
create approval-required workflow runs. A writer must approve these when GitHub
requests it, and verify the actual required PR/merge checks before merging.
workflow_dispatch evidence is not automatically declared equivalent to required
PR checks. No automatic approval, auto-merge or new credential is introduced.

## Read-only post-deploy trace

`windows-promotion-readback.yaml` follows a successful Deploy production run, or
can be manually pointed at its exact run ID from master. It has only contents,
actions and pull-request read permissions, no production environment, SSH,
writer lock or deployment command.

It verifies the exact run/attempt-owned retained delivery ZIP by actual SHA256,
size and finite receipt member; a successful install job, producer and recorded
source acknowledgement are required. The ACK is explicitly archival and checked
against that run's time interval, not presented as a fresh runtime observation
now. Source files are read from the proven deployed commit. The matching Windows
intent is linked to its introduced merge commit, associated merged review PR and
exact candidate-CI proof. Publication metadata/tag is rechecked again.

Later changes to other catalog selectors may survive alongside this Windows
promotion: the original delta is verified at its own merge, the deployed commit
must descend from it, and the deployed Windows target must still match. The
endpoint must match the *deployed source catalog*, including its current catalog
revision and full intended policy, not a stale older promotion revision.

Only the fixed public selector URL is requested, using GET without cookies or
authorization and refusing redirects. Exact revision, selector, full target and
URLs must match source. HTTP 200, JSON, no-store, nosniff and absent/zero Age are
required; cache-propagation retries are bounded. Reports retain hashes and safe
header flags, not response bodies/credentials. A rerun/replacement during proof
collection fails. A source without a matching promotion intent reports NOT_RUN;
this is not promotion acceptance merely because the readback workflow is green.

The final public trace links source, original candidate CI, review PR, merge,
build/deploy and endpoint with PASS/FAIL/NOT_RUN. Human review and physical
acceptance are never inferred from workflow success. The physical gate remains
NOT_RUN/#249 even when the catalog chain passes. Publication/input/CI/review and
readback artifacts are SHA/run/attempt-bound and retained for 30 days.

Local focused checks:

```sh
python3 -m unittest tools.release.windows_promotion.test_intent tools.release.windows_promotion.test_source tools.release.windows_promotion.test_ci tools.release.windows_promotion.test_deployment tools.release.windows_promotion.test_endpoint tools.release.windows_promotion.test_review tools.release.windows_promotion.test_release tools.release.windows_promotion.test_workflow
```

A separate current public endpoint observation is in
`evidence/ci/windows-promotion-endpoint-2026-10-19.json`: revision 29, Windows
1.0.38 (71), exact policy equality with the source catalog, no-store/nosniff PASS.
It is a catalog-only observation; installed server source, a new promotion chain
and actual old-client update are not verified by that record.

The new complete live promotion/CI/review/merge/deploy/readback journey is NOT_RUN
in this implementation turn. Per owner, long repeated runs are deferred until
implementation is complete. No production catalog was mutated for validation.
