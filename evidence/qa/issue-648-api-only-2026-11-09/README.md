# Issue 648: API-only outage with Android and Web

2026-11-09, integrated candidate `be97f71727a6d263390ebe13c30ad93228c71760`.
An Android 15 emulator and headless Chromium used separate synthetic accounts
against an isolated API, PostgreSQL and LiveKit. The owner-checked controller
stopped only the API for 130 seconds. An independent owner-checked inspection
during the interval reported API `exited` and SFU `running`.

Android sampled the voice state once per second over 160 iterations starting
at its ready marker. All samples remained listener/connected in the original
room: zero interruption samples. After API restoration Android reported a
fresh roster with at least two participants and the other participant's name
was visible. Chromium independently checked its connected state and an
authenticated roster of at least two while Android was still present. Both
processes exited 0. A source-resolution 1080 x 2400 Android screenshot showed
two synthetic users and a voice dock with two participants; SHA-256
`251279fe9cf9d456200a9c0c6e17b02e7a61421e81bcfb07a02b9422b0471da8`.

This is sampled UI/state and roster evidence, not proof of uninterrupted RTP,
audibility or physical-device behavior. It does not replace API/SFU combined,
SFU-only, canonical feature, production, iOS/macOS or other issue acceptance
gates. Scripts are retained here, and the owned stack, emulator reverse
mappings and temporary app were cleaned up. No deployment was performed.
