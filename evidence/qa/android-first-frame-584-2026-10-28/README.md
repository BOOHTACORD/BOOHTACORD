# Android stationary initial image, issue #584

Status: **REPRODUCED_BEFORE_FIX**. Signed physical verification of the correction is **NOT_RUN** at this implementation checkpoint. This record does not close #584 or parent media gates.

## Physical baseline

Samsung SM-A576B, Android 16, installed signed 1.0.47+2082. The APK was read without app data and its SHA-256 rechecked: `c7262608f5b5abbd722aa30428fe09d1532530026026d738837c14a884ea6243`, matching source `072426d60b1c0b1f7e5f66722a0da5faa00b50d7`. Two controlled MEMBER Chrome receivers used production Web source `4511c532743e209529db3dd8984f7542e0baa866`; backend source is UNKNOWN.

Only public Settings → Display was selected app-only. The exact picker card was reviewed at source resolution; subsequent cards matched its SHA-256. No settings values were changed by source motion. USB stay-awake was temporarily enabled after the first uncontrolled attempt showed a visibility transition. Voice/microphone stayed connected across owned capture stop/restart.

- Fast selection: 8 seconds in the app-source picker. Both receivers opened the publication. During a 30-second observation neither received video RTP or decoded/presented source frames. Native publication succeeded but sender video stats remained unavailable.
- Scrolling only the observed Display RecyclerView immediately restored both receivers: 8/9 decoded and presented frames, VP8 590×1280.
- Delayed selection: 153 seconds. A receiver snapshot again showed no inbound video, zero dimensions/decoded frames, and native stats remained unavailable until source motion. The harness incorrectly accepted an old 8×8 ended-stream presentation callback; that PASS is invalidated explicitly in `baseline.json`. This run does not claim a measured 30-second presentation deadline.
- After motion in the delayed run, both receivers had 10 decoded/presented frames at 590×1280. Bottom-dock Stop released screen FGS and projection while retaining microphone FGS and voice.

`baseline.json` keeps receiver snapshots and both cleanup receipts. `sender-*.json` retain only allowlisted lifecycle enums and numeric counters. No raw log, audio, media recording, credentials, user identifiers or message bodies are retained.

## Localization and correction

The exact cached `io.github.webrtc-sdk:android:150.7871.01` classes were inspected with `javap`. `SurfaceTextureHelper$3.run` assigns the listener, calls `updateTexImage` when `hasPendingTexture` is true, then clears that pending flag without delivering it. Cached `classes.jar` SHA-256: `2789e444c63f5b9b5f9f1ba227d12fbc03dfe617d6b83c0192b426730b3d8989`.

The previous capturer created VirtualDisplay before attaching this listener. A stationary first image can therefore be discarded. Separately, capture starts before the VideoTrack and publisher are ready; a stationary source supplies no later frame for a ready or late subscriber. The physical baseline confirms motion-dependent starvation before receiver RTP; it did not directly measure which initial-frame loss window fired in each failed run.

The correction attaches the texture listener before starting the producer. Once a real, visible source frame exists, a single capture-thread callback asks `SurfaceTextureHelper.forceFrame()` for the current texture after a second without a new source frame. It retains no buffer between callbacks. Duplicate SurfaceTexture timestamps are advanced by elapsed monotonic time so the encoder can accept repeated stationary content. Fresh source timestamps remain intact when they are newer.

Visibility loss cancels refresh and invalidates the old image; becoming visible alone cannot replay it. Stop, disposal and old generations cannot continue refresh. Existing profile cadence and orientation handling remain in place. Safe native counters distinguish unique source timestamps, delivered frames and refresh requests.

Upstream reference: [SurfaceTextureHelper](https://webrtc.googlesource.com/src/+/refs/heads/main/sdk/android/api/org/webrtc/SurfaceTextureHelper.java), inspected 2026-10-28. API/source semantics were also checked against the actual pinned binary; upstream HEAD alone was not treated as version proof.

## Checks and remaining acceptance

`focused-validation.json` records 34/34 Android plugin JUnit tests, including ten new refresh/timestamp regressions, and four focused Flutter contract tests. Local SDK is Flutter 3.47.5/Java 21; pinned CI must independently validate Flutter 3.47.7/Java 17.

The required `check.sh --feature screen --base origin/master --real-stack --platform android` first rejected registry-overlap coverage. Repeating with the additionally required auth/connection_status/voice features produced `.out/local-features/20261028-234534/report.json`: BLOCKED. The generic runner cannot launch its Flutter subprocesses or find an owned QA emulator on this Windows host; physical Samsung is intentionally excluded by that runner. This is not a media PASS.

Before closure: signed source-bound correction candidate; at least three fast/delayed stationary-source cycles; fresh RTP/decode/presentation times on each receiver's own monotonic clock; source-resolution receiver screenshot review; capture/encoder milestones on the phone's clock; voice-preserving stop/restart and no residual projection/FGS/refresh/polling. Never subtract clocks across devices. No capacity, calibrated FPS, general failure rate or platform-wide acceptance claim.
