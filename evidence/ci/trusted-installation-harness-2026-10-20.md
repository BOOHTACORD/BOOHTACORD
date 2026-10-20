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

## Native Linux run after the dependency correction

PR #461 merged as `edb6c71d30705cef56532af81fe734a213f7e9ce`, tree
`f21e2735724ea312f1f258bb4bd183179fef96a7`, after all 25 checks passed.
[Run 39346655478](https://github.com/Egkurilov/BOOHTACORD/actions/runs/39346655478),
job 118380773873, completed **FAIL in the interrupted-install case**. Its guard
suite passed; both full genuine QA builds passed OCI/import/smoke/sign/package and
owned-storage cleanup. Source-qualified installation, upgrade and same-SHA retry
passed, with unchanged recorded volume/network/logical fingerprints. The next
observed phase was interrupted maintenance, then the controller failed. The old
report omitted the exact interrupted receipt/lock/maintenance guard. The cause is
**UNVERIFIED**; no signal/maintenance race is asserted as a proven root cause.

Artifact 12230774786 was verified independently: 823372 bytes, SHA256
`f941c5740feb7b51b887c29953606968db81bd69cc5dbe8ecaef26db3d8c9324`.
All 58 origin harness hashes matched exact Git source, and all 56 builder hashes
matched the current builder. Three ACKs, immutable running indices and four stable
fingerprint observations were independently checked. Historical ACK inspection
used the authenticated job completion time; it did not claim a fresh ACK now.
The [partial record](trusted-installation-partial-2026-10-20.json) retains original
FAIL/RUNNING markers and all component facts. The terminal parent cleaned its
resources; the browser's original RUNNING marker is not evidence of a live process.

Nonoverlapping root build intervals were 247.078470 s cold and 69.696671 s warm;
nested image/package timings are not added a second time. Both private cache
namespaces remained the same, warm imports were VERIFIED and both storage owners
removed their images, worker/state and smoke resources. This is one hosted x64
fixture pair, including compiler-image warming, not a self-hosted performance or
production deployment result. Four of sixteen original PNGs were reviewed: stable
TEXT/attachment/member/composer content is visible, and maintenance banners are
visible. The maintenance layout clips lower footer/member content at 1200x800;
that observation is retained and no screenshot baseline is changed. This partial
record cannot close #394, #395 or #401.

The next candidate keeps every interruption guard and adds finite persisted
signal/receipt/lock/maintenance checkpoints plus source-frame diagnostics from
private logs. Focused tests first reproduced the missing checkpoint. A separate
historical ACK regression demonstrated that a long scenario needs recorded live
validation times, request nonces and an explicit trusted execution window; the
new QA-only reader leaves production's five-minute freshness check unchanged.
Malformed/private timestamp errors are sanitized. The next scenario also checks
a preserved non-default role policy and real MEMBER/admin and nonparticipant DM
denials in every browser phase. Complete runtime, recovery/rollback, all negatives
and 30-capture review remain **NOT_RUN** for these new checks.
