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

## First actual dispatch and dependency correction

PR #460 merged as `36d12a890b4aba59d8d10d96579d41f3dd6a3543`, tree
`85efc80f873043abe98f07713d60c995aa266fde`. All 24 core CI jobs and the
independent read-only transport check passed (25 checks). The exact manual
`installation=true` run [39344397026](https://github.com/Egkurilov/BOOHTACORD/actions/runs/39344397026),
job 118373400344, finished **FAIL before runtime**. Its first existing 42 rollback
guards passed; the new guard step ran 17 tests with one import error:
`ModuleNotFoundError: No module named 'yaml'` in `test_runtime_workflow`.
The final artifact upload also failed because no runtime output had been created.
No runtime bundle build/signing setup, sshd or application stack started. Unit
fixtures used only their temporary test keys, as in the local focused suite.

Cause: the static YAML workflow test had been added to a manual environment
without PyYAML. It already runs in mandatory contracts CI, which installs the
declared verification dependencies. The correction removes only that redundant
static module from the live guard command. All functional/isolation tests remain;
no assertion, required status, approval, source/signature guard or product code
was disabled. A new regression executes that exact command with `python -S` and
first reproduced the same missing-YAML failure locally. It now passes using only
the standard library; the full 24 trusted-delivery tests pass, including this
subprocess check, in 0.228 s. Actionlint and diff checks pass.

The original hosted failure remains FAIL, not a flake or a successful runtime
acceptance. A fresh actual run is required only after the corrected protected
source is merged. Installation/interruption/rollback, visual review and #395
closure remain NOT_RUN/OPEN at this checkpoint.
