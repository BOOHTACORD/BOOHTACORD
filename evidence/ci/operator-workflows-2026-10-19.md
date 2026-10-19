# #399 — manual operator capability implementation

Date: 2026-10-19. Baseline: b48d85c920ee067121f453575005cdc6bf27d5c8.
Before publication the change was rebased onto 7930ac782d6d08bb2caba701f8ff956ed65df497
(owner-merged password-reset PR #438, nine unrelated files, no overlap).
Parent: #382. Implementation priority requested by the owner: focused tests only;
no production operator execution or long acceptance rehearsal in this change.

Implemented: explicit diagnostics/mutation matrix; dry-run default; exact source,
trusted dispatch, fresh run and operator confirmations; authenticated GitHub
run/environment review with independent approval for mutations; a separate
restricted diagnostic key/account and root-owned forced-command capability;
pinned finite SSH transport with ephemeral key cleanup; redacted audit receipts;
separate production-serialized Buildx mutation and guarded rollback. Probe shares
the host installer lock, uses a unique namespace and fails on cleanup/capability
failure. Preflight handles both tagged and OCI-referenced deployed images.
Existing retained/automatic install source and receipt guards remain unchanged.
The always-running contracts gate now tests operator and actual-acceptance guards.
Backlog dependency IDs follow the issue dependencies (#386 is CICD-04).

## Local validation — PASS

- 42 focused Python tests, 3.511s: operator plans, missing/self/stale approvals,
  wrong repository/ref/SHA/observers, arbitrary read-only SSH commands and mutable
  capabilities, source drift, unavailable host, secret omission, ephemeral key
  cleanup, diagnostics/writer queue separation and existing delivery/trust edges.
- QA-11 Bash read-only fixtures (tag and OCI images), QA-08 active/released/failed
  reservation fixtures and QA-12 manual workflow source contract: PASS.
- Buildx probe Bash syntax: PASS. No Docker build/probe was performed.
- actionlint 1.7.11: PASS.
- Actions reviewed commit/trust inventory: PASS (32 workflows / 2 local actions).
- Auxiliary SDK and delivery workflow policies: PASS.
- Spec traceability: PASS_INDEX_ONLY (39 requirements); approved Windows brief
  unavailable on this Mac.

## External configuration / actual acceptance — BLOCKED / NOT_RUN

No production SSH connection, environment approval or host mutation was attempted.
Owner environment/reviewer/master-only settings, diagnostic account, root-owned
forced-command deployment, restricted key/sudo permissions and real approval/SSH
positive/negative runs remain unverified. Until configured and verified, real
operator requests fail closed; dry-run emits NOT_RUN. No local fixture claims a
production PASS, and #399 remains open. See docs/ci/operator-workflows.md for the
configuration matrix, audit interpretation and safe interruption procedure.
No backup, snapshot flow, database dump or global Docker prune is introduced.
