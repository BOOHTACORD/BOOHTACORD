# CICD-12 local verification, not a release acceptance

Parent #382; leaf #386 remains open. Current reviewed implementation pins 11 Actions
and exact-source actionlint across 26 workflows, validates all YAML uses forms,
locks declared publisher scopes/runner/ref/environment boundaries and preserves
existing release-signing queues. The inert legacy policy view is emitted only
under ignored .out after pin validation; runnable workflows retain full commits.

Local results: 592 project-owned Python tests PASS (39.345 seconds); the 22 focused
pin/trust/linter/release-boundary tests PASS; workflow policy and exact-source
Go 1.26.4 actionlint PASS. Requirement traceability: 39 IDs, PASS_INDEX_ONLY because
the approved product brief is unavailable on this host. ShellCheck and pyflakes
are NOT_RUN by this actionlint invocation; application/native acceptance is not
inferred from these tools checks.

Negative cases include mutable/unapproved/flow-style action references, invalid
YAML, secret context/bracket/root-env access, persistent/dynamic/group runners on
untrusted paths, inherited secrets, guard bypasses, unexpected publisher scopes,
unsigned and foreign-signed manifests, foreign producer/source and private-text
canaries in failure output. Job/step soft-failure mutations are rejected inside
reusable quality jobs as well as callers; the new test was observed red for both
variants before the policy correction. Existing exact-SHA artifact and rollback guards remain.

A static comparison against #411 confirms identical effective token scopes and
workflow queue declarations for all seven existing publisher jobs. The catalog
job keeps contents/actions/PR write; the other six keep contents write. Quality
jobs lose inherited write access. This comparison does not prove new environment/
ref restrictions or an actual publish. Native release/QA scope acceptance remains
NOT_RUN. Exact-source compatible rollback regression remains pending. Its retained inputs
now require successful actual master CI or signed Build server producers with all
three exact quality jobs; PR/merge-queue/feature-dispatch runs, wrapper skips, a
missing/failed bundle, duplicate or foreign jobs cannot be relabeled as master
quality. The reviewed current product/release inputs match master
`f65f22835d2c32134a2f1eaa2f9855fafa112509`; previous source
`bfea46b61c3bc641098caf7c35be8c4be798af59` has identical backend/contracts/deploy.
Current signed producer 39168026909 completed successfully with all five jobs;
previous signed producer 39155159380 also passed. [The master-input JSON](hardening-master-inputs-2026-10-19.json) records the exact successful source/run/job/tree bindings and observer hashes.
These are quality input proofs; hosted rollback and native publication remain
NOT_RUN at this checkpoint. Only the named non-runtime workflow
unit-test adaptor can differ from the retained release-tool input set; temporary
Git tests reject other runtime/toolchain/test differences.

Workflow-policy mutation tests also bind the producer caller/child display names
to the actual deploy decoder, preventing qualified-success vs bare-wrapper-skip
identity drift from silently reappearing. These local tests do not replace an
actual master no-release consumer observation (#384).

External GitHub settings remain unverified. The browser settings page was signed
out; branch-protection API read returned 403 (integration lacks administration
access), while the ruleset collection was empty. An empty ruleset list does not
prove classic branch protection, production approvals or runner/tag isolation.
No settings, credentials or trust anchor were changed. Required-status setup is
owner-managed. None of these missing gates can close #386 or parent #382.

Hosted acceptance exposed two pre-existing fixture failures after the pinned
workflows were activated. Their observed failures, focused corrections, native
file-path transport control and remaining actual CI acceptance are recorded in
[the fixture follow-up](hardening-acceptance-fixtures-2026-10-19.md). No failing
acceptance was removed, relaxed or promoted to PASS.
