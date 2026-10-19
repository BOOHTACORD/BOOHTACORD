# #395: isolated shipping installation acceptance candidate

Base: `f19b33484ac49144332d6f1546a815eff43f9743` (merged #459).
Scope: QA harness and an opt-in manual hosted Linux workflow; production
installation/signing/environment policy and all product sources are unchanged.

The candidate adds fresh full attested QA builds with a bounded private layer
cache, two browser observers, shipping loopback SSH installation, same-source
retry, client interruption during remote maintenance, independent lock/health
readback, recovery retry, canonical compatible rollback/restore, and actual
SSH/SCP/immutable/downgrade/health negatives. Existing retained producer proof and
runtime currency guards remain mandatory. The QA signing key is deleted; the
immutable collision is signed with that same anchor before key deletion.

Source roles are explicit: the original `current` is the newer qualified source;
`previous` is its qualified ancestor. Only the private setup roles are adapted
so the initial deployed source is older. Sources, gate receipts and image labels
are never renamed. Remote completion after interrupted SSH remains UNKNOWN;
recovery requires a released canonical lock and independent healthy unchanged
state. Original unexpected negative outcomes survive as FAIL receipts.

Focused TDD first observed missing-module errors and a missing opt-in workflow
input (8 initial errors), then the separate interruption and strict full-evidence
interfaces failed before their implementation. After implementation:

- 115 nearest QA/isolation/provenance/artifact-policy/trust tests PASS, 1.870 s.
- After the partial-negative retention change, all 22 trusted-delivery tests
  PASS, 0.094 s, including preservation of an unexpected original failure stage.
- A further focused check reproduced loss of the original unexpected-success
  receipt before rejection. The reader now retains that receipt before refusing
  the negative. All 23 delivery tests PASS after this correction; the original
  focused failure is not classified as an infrastructure flake.
- Node syntax check, actionlint 1.7.11, reviewed Action pins (34 workflows,
  2 local actions), toolchain/auxiliary policy and `git diff --check` PASS.
- Expected red diagnostic output from artifact-policy negative fixtures is not
  a runtime failure or a suppressed failing test. A mistaken invocation of the
  artifact capture runner without its required CLI arguments returned usage 2;
  the applicable policy test modules were then selected explicitly.

Actual native-x64 full build/install/retry/interruption/fault/rollback execution,
30-capture visual review and final resource-cleanup evidence: **NOT_RUN** for this
candidate. No local VM, production SSH, production credential, Keychain or native
application was used by these focused checks. This record cannot close #394,
#395, #386, #399, #401 or the epic. It does not establish a self-hosted performance
win, physical/native updater acceptance, production approval or owner cutover GO.

The manual default still runs the existing rollback scenario; `installation=true`
is the new combined scenario. Only generated public reports, actual public builder
metrics and synthetic images are retained; private logs and credentials remain
outside the artifact allowlist. The following live run must retain original
outcomes without assertion retries or treating an unrelated failure as PASS.
