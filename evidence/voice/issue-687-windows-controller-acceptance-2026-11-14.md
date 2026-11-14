# Issue 687: actual Windows audio controller acceptance

## DeepFilter continuous capture: PASS for the bounded transport check

An isolated optimized, research-marked Windows client used the production
AudioDeviceController, native Auto preflight, capture options and recovery
monitor against temporary private LiveKit. Receiver playback stayed muted.
No installed-client preferences, PCM, SDP or credentials were retained.

Source 0a3dc717ef5c9ed99a6003c1e596a869321c4d13; Dart AOT SHA-256
9823f861786ce14862c2681da4e6bf595292a2e9ecc74e5b1f5f0be92ba4dc19.
The pinned static-CRT DF DLL/model hashes match the earlier cold-start evidence.
Result: `.out/audio-research/auto-df-controller-endurance-1114-v2.json`.

All 360 intervals advanced across 1,800 seconds: minimum 442 processed frames
and 22 received RTP packets per interval, total processed delta 180,009,
8,685 received packets and zero fallback delta. Requested Auto, effective
DeepFilter, active, 16 kHz mono; firstNativeFailure null. Sixty owned-process
memory samples were retained separately, without a leak-free conclusion.
The earlier core-only 870-second failure remains unexplained and is not erased
by this passing rerun. This run does not prove real speech, listening quality,
end-to-end latency, full workspace recovery or production acceptance.

## Controls matrix: configuration/transport PASS; input switching BLOCKED

Separate optimized candidates use the same native plugin and production
controller, with the new controls probe. Both tested AEC/AGC 0/0, 0/1, 1/0,
1/1, followed by a processing change while muted and explicit unmute.
Each unmuted row requires six seconds of the expected active Auto-selected
engine, advancing processed/RTP counters, unchanged fallback and preserved
capture options with browser NS disabled. Muted processing must leave the
publication and media track disabled for two seconds.

| Candidate | Four AEC/AGC rows | Muted change / resumed capture | Two-device round trip |
| --- | --- | --- | --- |
| RNNoise v0.2 | PASS; 597-598 frames per row | PASS; 598 frames after unmute | BLOCKED |
| DeepFilterNet3 | PASS; 540-542 frames per row | PASS; 541 frames after unmute | BLOCKED |

The client's native inventory exposed fewer than two distinct non-alias input
devices. Both overall runs therefore exited 1 with deviceStatus BLOCKED.
No second device, route switch, hotplug or acoustic AEC/AGC effect is claimed.
Results: `.out/audio-research/auto-rn-controls-1114-v1.json` and
`.out/audio-research/auto-df-controls-1114-v3.json`. These binaries were assembled
before the diagnostic stage label was corrected from recovery to controls;
the structured controls object retains the actual blocked boundary/rows.
The correction changes reporting only and does not turn either run green.

Probe source: QA branch 3ccafe55a, application imports/native plugin from the
main research worktree; AOT SHA-256 RNNoise
8c39fc8bb05ccc5084c9eac11509a998dcb3ced2555d227bf9daa5a1af07704d;
DeepFilter 7262df99b8c09b1d4acc695cb486af779662e9d004bbc0117b70781d31e047cb.
Targeted Dart analysis passes in the QA checkout's configured Flutter package
context; normalized source matches the main checkout. An unconfigured root
invocation could not resolve package imports. Optimized builds pass. Artifacts were not
installed or published. Overall issue acceptance, adaptation/UI, speech/blind
trials, weight rights, notices, trusted signing and release/rollback remain open.
No server deployment.
