# Windows catalog promotion ownership

PR #793 normal pull-request CI rejected a newly generated immutable promotion
intent JSON under deploy/client-updates/promotions/. The earlier exact-head
workflow_dispatch run was green; only the PR-only new-runtime-path gate revealed
the missing ownership. The candidate was closed unmerged and its catalog was
not deployed. Repository master requires strict up-to-date ci-required checks.

The existing client.update-awareness feature now links a delivery component
for the promotion controller and runtime catalog. Its ownership scope is exactly
deploy/client-updates/promotions/, rather than the broader deployment tree.
Feature implementation/applicability values stay UNKNOWN. No promotion-intent,
release-asset or source-authority validation is changed.

Two regression cases failed before the mapping/scope change: future intent data
had no feature/component, and the narrow delivery scope was not supported.
After the fix, all 20 ownership scope/new-path/coverage tests passed. The actual
catalog maps future intent records; sibling deployment data remains unclassified.
Broad deploy/ and deploy/client-updates/ scopes remain rejected. These cases are
in the existing test_scopes module, already executed by ordinary contracts CI.

Catalog transition validation preserves all 27 prior feature and 88 prior
component identities. The parity projection and regenerated viewer freshness
check pass. A fresh exact-master two-file Windows candidate must be generated
after the source changes merge; the rejected candidate is not amended to bypass
its exact-file invariant. GitHub Actions PR-creation permission stays disabled;
maintainer PR creation can retain the verified intent/CI marker when needed.
