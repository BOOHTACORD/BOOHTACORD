# #394 implementation checkpoint — 2026-10-19

Scope: implement the epic analysis with focused tests/basic CI, deferring lengthy
runtime rehearsals to the combined acceptance stage per the owner's latest request.

Added private dependency/toolchain-scoped local Buildx cache, explicit digest/blob
verification, exclusive lease and bounded per-service export rotation. Go/npm cache
mounts share that namespace. Moved changing Web release arguments after the npm
dependency layer. Source labels, SBOM/provenance, actual OCI checks, real smoke,
strict gate receipts, signing and exact transport pair are still mandatory.

Actual stage timing records and an independent30-day source/run/attempt metrics
artifact make later cold/warm comparison possible. `WARM_VERIFIED` records import
selection, not a measured layer hit or quality PASS. Failed stages retain only fixed
phase/status/time fields; no signing input or command/exception output is captured.

TDD: cache/timing tests failed for absent modules before implementation, then passed.
Focused suite:39 tests PASS,0.916s, including corruption/mismatch/link/lease/size,
cache-hit OCI verification and foreign-source rejection, Dockerfile layer order,
receipt/signature/manifest/source and workflow integration controls. Syntax and
pinned Actionlint passed. Workflow/trace checks are recorded after final integration.

NOT_RUN: actual new cold/warm signed bundles, performance gain, complete Docker
data-root growth and operational rollout. Export retention is bounded; in-progress
export is not a filesystem quota, and existing internal BuildKit cache GC is separate.
No whole-suite repeat, VM, production retry or signing-account prompt was used.

Final focused validation: **59 tests PASS,2.031s**. Added a real tiny attested OCI
package/signature/transport-checksum check, a linked metadata RED→GREEN regression
and a producer selector control proving metrics stay outside the reserved `server-`
bundle namespace. Metrics use `build-metrics-server-...`; strict bundle ownership
checks were preserved. Full workflow policy31/2, pinned Actionlint, shell/Python
syntax and diff checks PASS; traceability PASS_INDEX_ONLY39 (approved brief absent).
No full application suite or full release was rerun for this checkpoint.
