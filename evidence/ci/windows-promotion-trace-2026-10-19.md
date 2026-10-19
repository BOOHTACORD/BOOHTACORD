# #397 — Windows promotion trace implementation

Implemented: strict source-bound immutable intent; exact-selector CAS and
monotonic order/build/version; complete current Windows release/checksum support;
separate branch/CI/review permissions; deterministic safe branch and PR reuse;
fresh CI registration/run/attempt/required-job proof; current master/branch/assets
rechecks; actual PR/merge-queue stale-intent rejection; read-only post-deploy
archive/source/PR/CI/merge/catalog tracing with bounded GET/cache validation.
No automatic merge, production mutation or installed-client driver added.

Focused TDD initially failed with missing intent/endpoint/workflow modules. Tests
cover actual local Git candidates, stale catalog/racing revision, frozen-intent
rewrites, foreign/partial releases, other-selector modification, order/build/
version downgrade, wrong SHA/attempt/required job, historical CI reuse, duplicate
or conflicting open reviews, actual retained ZIP hashes/ownership, archived ACK
time/source and stale public policy/cache/URL. These are unit/native-tool tests,
not a simulated claim that a live promotion completed.

One actual public unauthenticated GET was made, without cookies or mutation.
`windows-promotion-endpoint-2026-10-19.json` records exact current source-policy
match: catalog revision 29, Windows 1.0.38 build 71, no-store and nosniff PASS.
The reference source commit is a catalog reference only, not an installed server
source observation. New promotion chain and installed-old-client acceptance:
NOT_RUN. This partial evidence will be linked to #249 without closing it.

Full new hosted candidate CI/review/merge/server deploy/readback integration and
physical old-client update remain NOT_RUN, deferred per owner's implementation-
first instruction. #397 remains open until its actual complete chain is checked;
#249 retains the physical update scope. Required branch settings and signing keys
were not changed.

Final focused checks: **43 PASS in 2.887 s** (new promotion modules plus existing
catalog/CI/release-security/source-trust/master-workflow regressions). Workflow
policy: **PASS**, 31 workflows and 2 local actions. Actionlint 1.7.11 and diff
check: **PASS**. Required traceability: **PASS_INDEX_ONLY**, 39 requirements; the
approved external brief is unavailable on this host. No repeated full native
suite or deployment rehearsal was run.
