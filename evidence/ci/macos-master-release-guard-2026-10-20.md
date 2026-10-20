# macOS master dispatch reaches the native release preflight — #396 / CICD-13

The shared source contract and publisher added in PR489 allow stable manual
master execution only when the already-existing canonical macOS/version tag
peels to the exact checkout/raw trigger. Inspection after PR492 found that the
macOS workflow job itself still required `inputs.dry_run` on master. A stable
dispatch therefore skipped the complete job before reaching that preflight.
The separate trust policy pinned the same obsolete condition, while the native
workflow contract did not check job-level source eligibility. Prior green
contract tests did not prove that this documented route could execute.

The macOS job now admits manual upstream master dispatch in either mode. Only
the mode filter is removed; the upstream/ref/manual-event checks, production
environment, independent review, contents scope, hosted runner, signing queue,
exact-tag/source preflight and candidate publication suppression are retained.
The trust policy explicitly pins the corrected condition. The shared native
workflow verifier also requires each platform's exact source guard, rejecting
both widened conditions and silently candidate-only/always-skipped jobs.
Android and Windows execution conditions do not change. No GitHub environment,
ruleset, reviewer, secret or tag is created or modified.

TDD: the actual macOS mode-filter regression and12 source-guard mutations failed
first (13 failures across2 tests). After implementation,41 focused Python tests
PASS in5.958s, including real local Git exact-tag/missing-tag/changed-commit,
manual-event/foreign-source negatives, native assets/workflow, independent trust
policy and delivery routing/workflow checks. Reviewed action-pin/trust policy
and actionlint for the changed workflow PASS. The normal contracts CI also runs
the repository's contract/traceability verifiers; its result belongs to the PR.

This record proves the code and workflow correction, not an actual macOS stable
publication. No stable release is dispatched, no version tag is moved to satisfy
the check, and no production approval is bypassed. Platform candidate builds and
stable publishing still need their actual protected-run evidence. #396 remains
open until its full acceptance requirements are met.
