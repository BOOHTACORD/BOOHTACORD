# Voice room event sounds — 2026-10-31

Task: VC-001. Web and Flutter announce human participant joins/leaves and explicit start/stop of viewing a remote stream. The setting is independent from the existing screen-share-start sound. Initial room population, reconnect churn, internal `voice-lease:` participants and navigation cleanup remain silent.

## Checks

- Web focused suite: 5 files, 25 tests passed.
- Web production build passed. Existing LiveKit chunking and large-bundle warnings remain.
- Flutter tracker and sound mapping tests: 5 passed; the voice-dock preference widget test passed.
- Focused Dart analysis: no issues found.
- Client parity validation, local feature test policy and spec traceability passed.
- The registered local-feature run passed Web browser feature checks, the complete Flutter unit suite and Flutter component captures. Generated captures were inspected at source resolution; this sound-only change does not alter layout.

## Runtime limits

- Android real-stack smoke did not reach the app. The isolated QA stack could not start `livekit/egress:v1.14.1`: its configured `/entrypoint.sh` is empty and the container exits with `exec format error`. An ephemeral numeric non-root UID override did not change that. No repository QA or production image was changed to bypass this failure.
- iOS runtime, physical device audio output and live multi-client event playback remain `NOT_RUN`/`NOT_VERIFIED`. Component and unit tests do not prove audible output.
- Browser real-stack voice/media acceptance remains unverified; browser feature checks alone do not prove LiveKit event playback.
