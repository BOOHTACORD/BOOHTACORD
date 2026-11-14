# Issue 687: native Auto cold start and physical capture

Status: PASS for bounded Windows research Auto/media tests; overall issue PARTIAL.
Route: T-074, native Auto capability preflight. Existing OFF/defaults preserved.
No installed-client replacement, recordings, production connection or deployment.

The first optimized cold run selected browser although the native v0.2 worker
was starting. The generic 350ms method timeout expired during native factory
bootstrap. Auto now allows capability access the remaining portion of its total
two-second deadline. Ordinary capture controls retain their 350ms timeout.
Regression tests cover a 450ms bootstrap, unresponsive two-second fallback,
pending worker, malformed capabilities and cancellation. Sixteen focused
Flutter tests and targeted analysis pass. Native default 25/25 and verified
local v0.2 26/26 CTests pass, including terminal preflight stage assertions.

The actual shared Dart Auto service and flutter_webrtc plugin were built with
release optimization and BOOHTA_AUTO_PROBE=true in separate marked local
research directories, without a research engine override. Experimental
DeepFilter availability is false/true in separate builds. These are not release
artifacts: the research marker prohibits their packaging and publication.
Physical microphone, AEC on, AGC off, browser NS off; receiver playback muted.
Only bounded state and packet/frame counters were retained, no PCM/SDP/tokens.

| Candidate / transport | Processed frames | Fallback | Received packets | Result |
| --- | ---: | ---: | ---: | --- |
| RNNoise / direct peers | 597 | 0 | 301 | PASS |
| RNNoise / private local LiveKit | 597 delta | 0 delta | 54 | PASS |
| DeepFilter / direct peers | 549 | 0 | 300 | PASS |
| DeepFilter / private local LiveKit | 543 delta | 0 delta | 140 | PASS |

Each phase sampled six seconds after preparation and reported requested=auto,
effective=expected candidate, status=active, mono 16k capture. RNNoise preflight
passed; observed p95/max us: 178/215 direct, 166/167 SFU. SFU runner used a
checksum-verified binary, ephemeral tokens, loopback signaling/private ICE,
wildcard-listener guards and owned-process cleanup. No test processes remain.
These local transport tests do not demonstrate speech preservation, AEC/AGC
effectiveness, real call quality, long-duration stability or deployment.

Local result prefix `.out/audio-research/auto-`: `rnnoise-direct-1114-v3.json`,
`rnnoise-sfu-1114-v1.json`, `deepfilter-direct-1114-v1.json`,
`deepfilter-sfu-1114-v1.json`. Source based on 1cd70589 plus this cold-start diff
and QA branch 4b6b68a plus optimized/SFU diagnostics. Binary hashes:

- Shared runner EXE: a3508acfa9b489536011aaf30f9ee22306c6fa06ba99d3b6744864ae1a4214c1.
- RNNoise Dart AOT: 8cdad66745007962b2fae313b18589047868c891e9d1bb67426be4b4b57dff05.
- DeepFilter Dart AOT: a759cdb695f853210ce177f5d43a5ec06d4c354fb2fc8a919b3f34ce3fd17100.
- Native DF DLL: a7d07b7b2231b5ed4afa5b3a2a1a812054cea5a25e007b27b5a309cf2a421f48.
- DF weights: c94d91f70911001c946e0fabb4aa9adc37045f45a03b56008cb0c8244cb63616.
- Local SFU: 951f9466cd4450b3c3c7f1a5830a05a9bb97cc11d93cf1be9ebcd3b47cc316d1.

The earlier debug zero-frame/zero-packet attempt remains FAIL; its complete
cause is unproven. Do not overwrite that result with the optimized evidence.
Web Auto performance/adaptation, product UI, device/reconnect/endurance,
real-speech blind trials, RNNoise weight rights, signing and releases remain
open. CI on 1cd70589 still failed Firefox remote mute peak 0.0001220703125
against <0.0001; no threshold change or claim of a green current CI.
