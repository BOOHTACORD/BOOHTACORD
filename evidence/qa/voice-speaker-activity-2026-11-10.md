# Active speaker reporting interval — 2026-11-10

## Scope and source

- Base revision: `4b96bba1caed983b254962a6a9f69d0c957e3de6`, with the working-tree change configuring `audio.update_interval: 150` in `deploy/livekit/livekit.yaml` (SHA-256 `44286cb21246581098ff5fd1f219245efbb576e29320c923409a696160c914c4`). LiveKit is pinned to v1.13.7; sensitivity and smoothing retain its defaults.
- This is a source-only change. Production deployment and effective production configuration: NOT_RUN.

## Isolated synthetic measurement

- A disposable local LiveKit v1.13.7 container and two browser SDK participants used a gated 440 Hz synthetic oscillator. Each of six trials began after the receiver observed the sender as inactive. Time was measured in the browser between setting oscillator gain above zero and receiving the sender in `ActiveSpeakersChanged`; this does not measure rendering, a physical microphone, or cross-device networks.
- With the 400 ms default: samples 271, 497, 508, 506, 512, 508 ms; mean 467 ms.
- With a 150 ms interval: samples 132, 24, 24, 24, 31, 25 ms; mean 43 ms.
- After the active event, each trial held a continuous signal for 600 ms and detected no inactive-speaker event. Six samples per configuration on one host are exploratory and do not establish a general latency distribution, false-positive rate, or capacity profile. The disposable measurement script was `/private/tmp/boohtacord-speaker-compare.cjs`, SHA-256 `59e1aded0d39f25031674b719b2d7599bcb3f1519aa2fa53a992d9cc1422f215`.
- Real microphone, paired physical clients, unstable networks, quiet speech and background-noise behavior: NOT_RUN.

## Local validation

- LiveKit configuration, historical artifact verification and local-feature policy: 24 Python tests PASS. Web unit suite and production build PASS; Web voice-interface browser suite PASS. Flutter component captures PASS. Full Flutter unit stage BLOCKED because one test was skipped (1,839 passed).
- Original QA run `.out/local-features/20261110-224245` is FAIL: Web dependencies were initially absent; four Android runtime stages then failed before application startup because the Colima VM did not mount this worktree and Tempo received a directory where its config file was expected. iOS runtime is BLOCKED because no QA simulator was available.
- Web-only rerun `.out/local-features/20261110-225225` is FAIL: one accessibility test failed during a page navigation (the same test passed in a separate targeted retry), a screen-profile scenario was skipped and marked BLOCKED, and both real-stack stages failed at the same Tempo configuration mount. Other listed Web stages passed. Its source-stability fingerprint applies to the source before the final source-only integrity record and verifier update; the tested LiveKit interval and audio-level configuration did not change afterwards.
- Source-resolution visual observations are in each run's `voice-visual-review.md`. Two Flutter captures and one Web voice-room capture were reviewed; the remaining captures and an actual speaking transition were not individually reviewed. Full visual/native media acceptance: NOT_RUN.
