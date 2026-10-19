# Manual production operator workflows (#399)

These workflows are **manual only**, upstream `master` only and use read-only
GitHub token permissions. They are not triggered by PRs. Product/build gates do
not claim that a dry-run or private host check is physical/media acceptance.

## Capability and approval matrix

| Workflow / job | Reads / changes | Environment / reviewer | Queue / limit | Exact inputs / evidence |
| --- | --- | --- | --- | --- |
| audit-attachment-volume / audit | Running API/Web source, capacity and health; no volume contents or DB rows | `production-diagnostics`; authenticated environment review | separate operator diagnostics, non-cancellable / 5min | deployed source, read-only confirmation; sanitized receipt / 30d |
| qa08-active-upload / sample | Controlled user's active reservation and release, aggregate capacity; creates no upload | `production-diagnostics`; environment review | diagnostics queue / 5min | deployed source, operator upload-ready, 2..120 samples; receipt / 30d |
| qa11-preflight / inspect | Docker/storage/Buildx inventory and running source; no build, upload or service change | `production-diagnostics`; environment review | diagnostics queue / 5min | deployed source, read-only confirmation; receipt / 30d |
| qa11-preflight / probe (optional) | Uploads pinned Buildx; creates unique temporary config, OCI output, image and stopped Compose test container; removes owned objects | `production`; independent reviewer, explicit temporary-build-probe confirmation | `v-bootybay-production`, cancellation disabled + host `.install.lock` / 15min | source, `run_probe=true`, confirmation; cleanup/capability result receipt / 30d |
| rehearse-compatible-rollback / rehearse | Temporarily deploys retained compatible images, observes and restores current; existing guarded compatibility/resource checks remain | `production`; independent reviewer, two authenticated browser observers and maintenance window | same production writer queue + existing installer host lock / 20min | exact current/previous SHA, observer confirmation, rollback-and-restore confirmation; receipt / 30d |
| install-retained-release / install | Existing #395 verified bundle installer, retained artifact only | `production`; owner-controlled environment approval | same production queue + host lock / 30min | exact build run/source; existing source-bound delivery receipts / 30d |
| deploy-production / install | Existing trusted completed master producer consumer (#395) | `production`; owner-controlled environment policy | same production queue + host lock / 30min | authenticated producer/attempt/artifact and fresh readback; existing receipts |

Read-only diagnostic jobs have their own SSH account `boohtacord-diag` and secret
`OPERATOR_DIAGNOSTIC_SSH_KEY`; they never receive the general deployment key.
Only the probe/rollback job receives `DEPLOY_SSH_PRIVATE_KEY`. A diagnostic job
cannot join the production writer queue. The optional Buildx probe used to run
inside a purportedly read-only preflight: it is now a separate explicit mutation.

## Owner setup and external acceptance — BLOCKED until configured

No repository settings or host accounts were changed by this implementation.
The owner must configure `production-diagnostics` and `production` environment
reviewers and master-only deployment rules, plus the dedicated diagnostic key.
The code additionally authenticates run metadata and environment reviews using
[GitHub's review-history API](https://docs.github.com/en/rest/actions/workflow-runs#get-the-review-history-for-a-workflow-run).
Missing approvals, unreadable API, rejected reviews or a self-approved mutation
are BLOCKED before SSH. Numeric actor/reviewer IDs are retained for audit; review
comments, usernames and API credentials are omitted. A run is valid only on
attempt 1: use a **fresh dispatch**, not rerun, because review history does not
prove fresh approval for a later attempt. No client-supplied approval boolean can
replace the authenticated review.

For the diagnostic account, install the following reviewed files from one exact
source under `/opt/boohtacord-operator/`, root-owned and not writable by group or
other; their full directory chains must also be root-owned and not symlinks:

- `tools/ops/operator/{remote.py,policy.py}`;
- `tools/release/delivery/{commands.py,current_revision.sh}`;
- `tools/release/preflight/preflight.sh`;
- `tools/ops/attachment_audit/audit-attachment-volume.sh`.

Configure its dedicated SSH key with `restrict` and the **forced command**
`/usr/bin/python3 -I -B /opt/boohtacord-operator/tools/ops/operator/remote.py`.
Disable password/interactive access and all forwarding/PTY for that account; keep
its authorized key root-managed. Its sudoers capability is limited to `bash`
executing those three root-owned read-only shell helpers (audit accepts only the
validated SHA). Do not grant Docker-group membership or general sudo/shell to
this account. The forced command accepts only versioned audit/sample/preflight
requests, checks deployed source before and after, clears client environment,
never accepts stdin code or an executable/path/host argument and emits only a
source-bound PASS marker. The client requires that marker. Arbitrary SSH, SCP,
install, rollback or shell text through the diagnostic key must fail.

Verify this configuration separately with controlled dry-run/negative and real
read-only executions before recording an external PASS. No production approval,
key restriction, live SSH result or rollback rehearsal is inferred from local
unit tests. Existing retained/automatic install environment settings also remain
an owner readback item; this change does not replace their existing #395 trust
and audit checks.

## Running and interpreting results

1. Dispatch the intended workflow on `master` with the **currently deployed**
   40-character source, which may be older than latest master. Leave
   `dry_run=true` to validate the plan without any host access: result NOT_RUN.
2. For real diagnostic access select the explicit confirmation and
   `dry_run=false`, then obtain the configured environment review. Sampling also
   needs a controlled user upload that spans at least two samples and finishes
   during the bounded window. The workflow itself never uploads user content.
3. For Buildx probing select `run_probe=true` and its separate mutation
   confirmation. The binary digest remains pinned. The job serializes with
   deploy/install/rollback, takes the same host lock, uses a unique temporary
   namespace and fails if capabilities or cleanup cannot be established.
4. For rollback, supply exact compatible retained sources, explicitly confirm
   rollback-and-restore and ensure the two observers/maintenance window are ready.
   Existing signed-bundle, identical backend/schema/topology and resource-identity
   checks remain authoritative. There is no bypass, backup or data-copy path.
5. Read the retained `operator-<operation>-<source>-<run>-<attempt>` receipt. PASS
   means this exact approved operation and required source/readback completed;
   NOT_RUN is a plan; BLOCKED means prerequisites failed before host execution;
   FAIL means an attempted operation did not complete. Missing artifact is red.

## Audit privacy and stopping safely

SSH uses a pinned public host key, strict identity/known-host verification,
no agent/port forwarding, no PTY, bounded connections, process groups and finite
output. Private keys and known-host files live in a 0700 runner temporary folder,
are 0600 and are removed even on error. Raw stdout/stderr, filesystem identities,
private IPs, metrics, package contents and credentials are not printed or
uploaded. Only the finite sanitized receipt is retained, including source,
operation, run/attempt, actor/reviewer IDs, result, phase and cleanup state.

Cancel diagnostics if needed; they have no mutation capability. Never cancel an
active production mutation merely to start another run. Actions cancellation is
disabled for competing writers; a forced human cancellation may still interrupt
a client. Guarded rollback handles interruption, but a lost connection cannot
prove remote restoration. Such a receipt says NOT_VERIFIED: inspect the running
source and host lock before any retry, using a fresh approved dispatch. Probe
cleanup failure is fatal; remove only its recorded owned namespace after diagnosis.
No global prune, backup, snapshot flow or `pg_dump` is introduced.
