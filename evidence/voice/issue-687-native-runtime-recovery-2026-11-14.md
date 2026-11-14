# Issue 687: native runtime recovery and sustained-test failure

Overall PARTIAL. No release or server deployment. Route: T-074 native Auto
runtime degradation and T-075 bounded actual-plugin acceptance.

The first continuous DeepFilter Auto research probe failed after 870 seconds:
174 intervals, 86,729 processed-frame delta, 249 fallback-frame delta, effective
unknown / initializing. Each interval required processing and RTP progress.
Its final JSON did not retain the native failure reason, so the exact failure
origin is unproven. Background compilation occurred during the run; causality
is not established. This probe used NativeNoiseSuppression without the normal
application recovery monitor. It does not prove the product lost audio, and is
not a 30-minute PASS. Result in QA checkout:
`.out/audio-research/auto-df-endurance-1114-v1.json`.

Memory observer retained 27 aggregate working-set/private-byte samples, with
no audio or process/user identifiers. It is observational, not a leak verdict.
Research DF client AOT SHA-256:
`586a9b6a048ea9f7dffca7d8f9a2ddbcaa07093a351f692e108953526fef1ca8`.

The next optimized probe uses the real AudioDeviceController for Auto
preparation, capture options and native recovery monitoring, bound only to a
temporary local SDK room, without account preferences or installed-client state.
Every replacement receiver track is muted; three focused tests validate first
and later mute success/failure. Source QA b5f0e5d73 plus current native source.
Its AOT SHA-256 is
`84db5c45fdb128f192a69cb3d628e97838c85a9c0285a0c6675d70919954569f`.

| DeepFilter local SDK interruption | Reconnected ms | Post-recovery frames delta | Fallback delta | Result |
| --- | ---: | ---: | ---: | --- |
| signal-only | 284 | 570 | 0 | PASS |
| full peer reconnect | 313 | 546 | 0 | PASS |
| full reconnect while muted | 358 | 531 | 0 | PASS |

Muted-full checked the publication stayed muted and its track disabled for two
seconds after reconnection before explicitly unmuting. Each recovery was
followed by another six-second progress interval. These are local SDK socket/
peer reconnections with a physical microphone, not a server restart, workspace
UI, remote production client, acoustic mute-leak or speech-quality acceptance.

A separate code regression reproduced Auto runtime degradation choosing browser
despite eligible RNNoise. The controller now tries measured RNNoise after a
DeepFilter failure, then browser when RNNoise is ineligible. Requested Auto,
AEC/AGC and mute intent are preserved. The backup uses a three-second total
recovery deadline; ordinary browser recovery retains 850ms. Stale scope/model
preparation cannot install a late engine or unmute. Nineteen focused Flutter
tests and targeted analysis pass; new runtime tier still needs physical failure
injection/endurance acceptance. No claim that this fixes the 870-second origin.

RNNoise's 30-minute continuous physical-capture run is pending. Full local Web
gate failures, acoustic/AEC/AGC/hotplug, adaptation/UI, rights, signed delivery,
cross-platform release acceptance and blind trials remain open.
