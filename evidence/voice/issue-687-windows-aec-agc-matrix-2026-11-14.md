# Issue 687: Windows capture flag matrix

Status: PARTIAL. On Windows 10.0.26300, a local-only research build based on `f07978af38f3605867480d9561abcca9d3c60508` plus the accompanying diagnostic changes captured a physical mono 16 kHz microphone, published to a temporary local LiveKit server, and switched RNNoise v0.2 → DeepFilterNet3 → RNNoise. Two SDK rooms ran in one process; receiver playout was muted. No speech or device IDs were recorded.

Each of the four combinations below was requested independently through LiveKit capture options. For each stage, the effective engine matched, processed-frame counts increased, sampled fallback count remained zero, one subscription was observed, and packets increased. A request flag is not evidence that native AEC or AGC was actually active or acoustically effective.

| Requested AEC | Requested AGC | Packet increases by stage | Aggregate result SHA-256 |
| --- | --- | --- | --- |
| off | off | 31, 19, 18 | `b513abdc1c2297ad54357f10a1904d50f5f5f46623a05887b7ddbe14a52d2a65` |
| off | on | 31, 20, 20 | `aa587d702addb6dc951d3ec98827703c5ff50a9a9ae977d28ee049454898b532` |
| on | off | 30, 20, 19 | `80d254c522e525b43dec3d239e6a125315994d9dcfa91e16cac9e0cfaa09ac60` |
| on | on | 18, 19, 18 | `cbba1a3b7f6db9e71d4ce82a9edfeee72cc70c2875523230a6df9b0fdef9d641` |

Diagnostic executable SHA-256 `e5c522519c1499f26fec7ba971da7c66ee6c25517f3ac9563b6e35497e83008d`; WebRTC plugin SHA-256 `e0e8f19d6726ab3116216d2542484d851f878fb6b182bffbc8994c447a4bcd83`. Model binaries remained local and marked research-only. The focused flag and packet-delta Flutter tests and Dart dependency audit passed.

CI on `f07978af38f3605867480d9561abcca9d3c60508` reported a Firefox receiver mute peak of 0.000122 against the <0.0001 gate. Five repeats of that single Firefox test on local Windows passed; platform differences prevent using this as a CI pass or a diagnosis. The threshold was not changed. NOT RUN: acoustic AEC/AGC effectiveness, real-speech quality, independent clients, long-duration stability, model rights and release acceptance. No server deployment was performed.
