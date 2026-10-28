# Samsung stationary first image — #584

**PASS for this physical Samsung scenario.** Code [PR #593](https://github.com/Egkurilov/BOOHTACORD/pull/593) is merged as `b7f1c3ad438201c0461ed4858d97df6917815ceb`. Six corrected-candidate cycles (three fast, three with a configured 150-second picker hold) delivered public Display images to both real Chrome receivers before any source scrolling. Every pair was inspected at its original decoded resolution, 590×1280.

## Candidate and controls

Samsung SM-A576B, Android 16/API36, signed 1.0.47+2082. Correction APK SHA-256 `c2a5489368980a66dedd291c2899ed946a86aa400c2229bcc43ba1363029bd8b`; unchanged production certificate `394e369de2d566b4897493ee498da2f27745e514c49ca88c6489b0b0a811212b`. Installed APK hashes were verified before and after the six cycles. [Official signing run](https://github.com/Egkurilov/BOOHTACORD/actions/runs/40771321004) used `dry_run=true`; source was clean and no release was published.

Two controlled MEMBER Chrome 155.0.8059.85 receivers used Web source `4511c532743e209529db3dd8984f7542e0baa866`, matching the baseline. Backend source is UNKNOWN. Browser microphone requests were zero, output muted. The source was app-only public Settings → Display; the reviewed picker-card hash matched on each run. No source setting value was changed. APK replacement retained the application session; the owned QA voice connection was explicitly restored after replacement.

## Before

[Current-master baseline](current-master-baseline.json) binds signed `b74fce609ad3ddbbfb0dbef81c5efae68195f20f` to APK `9e4715ff184a1afa606ed98a8d7f7d7110200ad88ccb9fa55888213d94256768`. Two fast selections and one 150-second hold each produced a 30-second first-frame failure on both receivers: no inbound video, no decoded frame, zero video dimensions. Public-source scrolling restored decode/presentation; [six after-motion images](baseline-after-motion/) were inspected. This is three observed runs, not a general failure-rate estimate.

[Earlier candidate baseline](baseline.json) and `sender-*.json` retain the original `072426d6` attempt, controller-selector failure, an invalidated stale 8×8 presentation PASS, and the uncontrolled visibility-transition attempt. Those observations were not silently upgraded to valid passes.

## Correction and localization

The capture listener is attached before VirtualDisplay starts its producer. The exact pinned WebRTC 150.7871.01 binary was inspected: `SurfaceTextureHelper$3.run` drains an already pending texture when assigning its listener. Cached `classes.jar` SHA-256: `2789e444c63f5b9b5f9f1ba227d12fbc03dfe617d6b83c0192b426730b3d8989`. [Upstream API reference](https://webrtc.googlesource.com/src/+/refs/heads/main/sdk/android/api/org/webrtc/SurfaceTextureHelper.java), inspected 2026-10-28, was checked against that binary.

After a real source frame and confirmed visibility, one capture-thread callback refreshes an idle texture at one-second intervals. No buffer is retained between calls. Repeated texture timestamps advance by elapsed monotonic time; newer source timestamps remain intact. Visibility loss invalidates refresh, including an already queued duplicate; stop/dispose cancel callbacks and stale generations cannot restart them.

Safe counters now separate unique source timestamps, forwarded frames and refresh requests. In cycle1 the first source callback was at 42ms after capture-helper startup; it preceded publication completion by 17ms and the visibility callback by 24ms. Initial source activity then settled at 51 unique timestamps; idle refresh continued forwarding the captured image. The first positive encoder sample was observed 3053ms after the first source log. Both receivers decoded/presented without source motion. Between visibility loss and Stop (about six seconds), cycle1's refresh-request count stayed at 16.

The historical failing runs did not have capture counters, so they cannot uniquely identify which initial-image loss window fired. The confirmed pre-fix symptom is starvation before receiver RTP, restored by motion. The correction covers listener startup and availability to a ready/late consumer; the physical before/after result and new pipeline observations are retained separately.

## After: six source-stationary cycles

| Sequence | Configured picker hold, s | Next-to-source-verified path, s | Phone source→first positive encoder sample, ms | Viewer B/C watch→observed presentation, ms | Result |
|---|---:|---:|---:|---:|---|
| 1 | 0 | 8 | 3053 | 1351 / 1324 | PASS |
| 3 | 150 | 153 | 3048 | 918 / 895 | PASS |
| 5 | 0 | 7 | 3019 | 1104 / 1090 | PASS |
| 7 | 150 | 153 | 3063 | 1119 / 1087 | PASS |
| 9 | 0 | 7 | 2056 | 1150 / 1127 | PASS |
| 11 | 150 | 153 | 2065 | 1148 / 1124 | PASS |

[Full acceptance data](acceptance.json) contain the separate RTP/decode/presentation observations, native counters, ten-second stable checkpoints and every stop receipt. [Twelve first images](fixed-first-image/) were extracted before source motion and reviewed at original resolution. A public Display scroll after the final first-image checkpoint additionally verifies continued moving-source delivery.

Phone intervals use the phone's log clock. Each receiver interval uses only that browser's performance clock, with 200ms polling. These are observation bounds, not calibrated end-to-end latency, p95 or an SLO; clocks from different devices were not subtracted. Unique SurfaceTexture timestamps are not a calibrated source FPS. No 60FPS, capacity, general failure-rate or platform-wide media claim is made.

## Cleanup and validation

All six Stops released projection and screen FGS while retaining voice and microphone FGS80. After the final Stop, 68 seconds contained no new screen capture/refresh/sampling/report events. Both owned browser receivers explicitly left. [Final cleanup](final-cleanup.json) records restoration of the temporary USB stay-awake setting and closure of the owned QA voice session; application session and microphone permission were retained. Only public still frames were saved; no audio/PCM/video recording, production fault/load, router, TLS or session reset was used.

[PR CI](https://github.com/Egkurilov/BOOHTACORD/actions/runs/40768240719) passed all 27 checks on `fe3205e9f999bd8b54449f9075b08c58ca25acc2`; the merged tree was verified identical. Local Android plugin JUnit: 35/35, including 11 new regressions; all reviewed plugins total 51 tests per Kotlin mode. Four focused Flutter contracts and six Python runner/result tests passed. The official candidate's pinned Flutter 3.47.7/Dart 3.13.5/Java 17 quality gates and signed build also passed.

The generic local-feature runner remains **BLOCKED on Windows**: the required screen command first required auth/connection_status/voice coverage because the registry overlaps; the complete selection then could not launch Flutter subprocesses or find an owned QA emulator. Its report is `.out/local-features/20261028-234534/report.json`. The dedicated physical scenario above is separately verified. Parent hardware/media gates #131/#132/#173 remain open; toolbar-Stop uncertainty from the original harness and unrelated #579/#48 are not claimed fixed here.
