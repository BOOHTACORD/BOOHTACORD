# Issue 687: measured Web runtime backup and Windows endurance

Status: scoped Web runtime backup PASS; overall acceptance PARTIAL.
Auto now tries measured RNNoise after an active DeepFilter failure, then
confirmed browser NS when RNNoise is ineligible. Recovery first silences the
old graph and respects the latest mute intent. Explicit modes retain their
existing browser recovery. Subsequent RNNoise health events preserve the
original fallback cause; a new profile preparation clears the old context.

Regression tests failed before the change for both muted/unmuted runtime
backup and loss of fallback reason on a health update. All 129 scoped noise
tests, 1,990 full Web tests, vue-tsc and default production build pass.

Three local Chromium tests through the private LiveKit passed: real pinned
WASM preflight, ordinary Auto DeepFilter publication/mute, and controlled
DeepFilter overload followed by real measured RNNoise v0.2. The fault test
substitutes a test-only worklet via the isolated context's addModule boundary;
an explicit counter requires exactly one substitution. It requires history
showing DeepFilter active, then RNNoise active with model identity and retained
overload reason after a further health update, and nonzero finite received
synthetic audio. It does not measure DeepFilter quality. Earlier attempts to
intercept worklet fetches with Playwright routes did not install the fault and
remain failed test attempts. No production URL/configuration was modified.

Local machine report:
`.out/audio-research/auto-preflight-20261114161449956.json`: three expected,
zero unexpected, zero skipped/flaky, 11 seconds. Research assets were served
from the verified external stage, with both model opt-ins; none were committed
or copied to public assets. This combined local config requires both opt-ins;
the separate auto_v02 config remains the RNNoise-only research entrypoint.

Separately, Windows RNNoise v0.2 passed 1,800 seconds of continuous physical
capture through private LiveKit, all 360 intervals progressing: minimum 494
processed frames and 22 received packets per interval; 180,093 processed-frame
delta, 8,602 packets, zero fallback delta. Requested Auto/effective RNNoise,
active, mono 16k. Source 48d886070 predecessor plus the already committed
monitor diagnostics, optimized marked client AOT SHA-256
`5a2aebe409d2cf0ad4e65bb17b64a045335d14f9a164aa79d4e729835e5ba0f6`.
Result: QA checkout `.out/audio-research/auto-rn-endurance-1114-v1.json`.
Sixty process-memory samples were observed; no leak conclusion is asserted.
No recordings or listening-quality claims. Native DeepFilter's controlled
30-minute rerun with production recovery monitoring is still pending.

The complete local Flutter run on 48d886070 passed 1,985 tests with three
platform skips; component capture/source stability passed, mobile runtime
remained BLOCKED. Eight relocated QA-helper regressions and both repository
import verifiers pass. Release rights/signing, adaptation/UI, actual speech,
AEC/AGC/device acceptance and blind trials remain open. No release/deployment.
