# Release recovery and native 1.0.51 — 2026-11-05

Task CICD-10 (dependencies CICD-01/09/12), REQ-DEPLOY-01 / REQ-QUALITY-02 / REQ-SECURITY-01. User authorized recovery, delivery to the installation and necessary client rebuilds.

Base: master `654bd8c95595211e6046e7291f1ee142caad34de`; no open product PRs were pending. Build server run 42000315686 passed all backend/Web/contracts/exact-master quality gates, but bundle job 127157131194 failed before image builds/signing. Metrics show 14,473,064,448 available bytes against the unchanged 14 GiB requirement (15,032,385,536 bytes). The newly pulled pinned Emscripten compiler image remained on the disposable runner after RNNoise compilation. Automatic deployment and catalog readback were consequently skipped. Earlier cancelled PR runs were superseded intermediate heads; final PR #654 CI passed all 27 checks.

Read-only production observation: API/Web were still `0a5d63e7bdee78a8565950dd98f8d0a4bc0d4002`, root filesystem approximately 19 GiB available. No production data/volumes were removed.

## Changes

- On disposable GitHub-hosted builds only, snapshot the compiler's exact digest reference before asset compilation. Remove only a newly acquired compiler reference after compilation, including failure cleanup, without force. Preserve pre-existing references, other tags and all local/self-hosted image stores. Do not prune the daemon, remove toolchains or lower the builder headroom requirement. Record the compiler cleanup result in build metrics.
- Prepare native 1.0.51 (87), release order 66, keeping the published 1.0.50 artifacts/tag immutable. Shared native defaults and canonical identities agree. Web identity is unchanged; the server bundle includes current Web source.
- Enable manual macOS stable dispatch from protected master, matching Android/Windows. The existing production environment, exact canonical tag/SHA/source preflight, asset checks and publisher remain mandatory; no repository environment policy or signing key changes.
- Shared version-label metadata only: no new interaction/visual behavior or media acceptance claim. Physical audio acceptance remains NOT_RUN under #655.

## Verification

- Compiler cleanup tests failed before implementation; five focused cases pass (fresh reference, pre-existing/foreign references, compile failure, local/self-hosted preservation and removal failure).
- 30 compiler/asset/builder-storage/metrics tests PASS.
- 42 source/workflow/trust/network tests PASS; macOS stable-dispatch regression failed before its guard change.
- Contracts verifier PASS: 20 tests and 129 public operations. Base-aware parity PASS. Historical network evidence remains immutable; source-only revalidation binds the updated shared registry/checker.
- Full Python verification PASS: 1,369 run / 9 skipped under Python 3.12; three focused client-identity test functions PASS. PR CI, actual hosted compiler-image reclamation, signed server bundle, production readback and native publications: pending; final run IDs and actual outcomes will be retained with the delivery result. Unit tests do not establish real reclamation or successful installation.
