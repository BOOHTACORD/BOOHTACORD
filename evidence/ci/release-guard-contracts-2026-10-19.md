# Release-only source-guard regression — 19 October 2026

After #420 merged as `ec7c832d61720c2f0d50707c96995c1b3bca02fa`,
[Build server 39180524394](https://github.com/Egkurilov/BOOHTACORD/actions/runs/39180524394)
failed its contracts job 117832128989 in the release-only negative guard suite.
The bundle job cannot proceed without a successful contracts gate. The seven
ordinary PR checks and four actual acceptance jobs for the earlier reviewed tree
remain valid in their stated scope; they did not execute this release-only path.
No successful production bundle/installation is inferred from those PR results.

The active-upload sampler and manual rollback source tests still searched for
`github.ref_name == 'master'`. The workflows now deliberately require the complete
upstream repository plus `refs/heads/master` expression and the production
environment. Both original tests failed before the correction and pass locally
after requiring that exact full line and environment. Manual-only triggers,
operator/observer readiness checks, serialization, SSH validation and all runtime
negative assertions remain intact. No production workflow guard is relaxed.

All 19 original negative test commands are extracted, in their original order,
into `tools/ci/release_guards/test-negative-boundaries.sh`. The full release guard
entrypoint retains its pinned dependency/bootstrap, Compose, contracts and
traceability checks and delegates to this same suite. Ordinary contracts CI runs
the suite when `release_receipt` is false; the existing full release entrypoint
runs it when the receipt input is true. Thus PRs now exercise these rejection
boundaries before merge without duplicating the suite within one job. No test
was removed, converted to advisory or conditioned on a cache hit.

Local checks: both corrected source/runtime shell tests PASS; exact comparison
confirms all 19 commands and their order are retained. Action pins/trust policy
and reviewed-source actionlint PASS. Full local suite is NOT_RUN with Apple's
system Bash 3.2: existing fixtures require Bash 4 features (`mapfile`, associative
arrays and uppercase expansion). The shared entrypoint reports this explicitly;
Linux CI executes the entire suite. Hosted acceptance and the next exact-master
release-gate result are required separately; this record does not mark them PASS.

No product/API/schema/deployment implementation, signing identity, permissions,
production environment rules or repository protection changes are included.
#386 and parent #382 remain open for their outstanding external/native acceptance.
