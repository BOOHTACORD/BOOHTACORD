# Flutter stream previews in voice participant cards

Task: FV2-060.

Date: 2026-10-29.

Branch: `codex/flutter-stream-participant-cards`.

Base: `754b5997ad100cb00300373f29ab88bda4ed267d` (`origin/master`).

## Changes

Flutter now places a live screen preview in the streamer's voice participant
card. Stream and voice-only cards share the same responsive dimensions; the
stream preview has a centered play affordance, live badge and screen-profile
caption, and opens the existing viewer when tapped. Voice-only cards show the
headphone status panel. Participant names are left-aligned, and avatar and
microphone status stay in the footer.

Screen thumbnails are bounded to 480×320 and the existing 14 KiB upload
contract. JPEG encoding tries a bounded quality ladder before reducing frame
dimensions. Capture retries once per second for up to ten initial failures;
after the first frame, capture and receiver refresh use a 30-second interval.

## Verification

- PASS: registered local-feature acceptance command:

  ```sh
  ./tools/qa/local_features/check.sh --feature screen --feature voice \
    --feature shell --feature auth --feature connection_status --feature support \
    --base origin/master --real-stack --platform android \
    --native-device android:emulator-5554
  ```

- PASS: Flutter full unit suite, 1,661 passed and 1 skipped.
- PASS: Flutter component capture suite, 359 passed.
- PASS: authenticated Android runtime smoke against the owned local API on
  `BOOHTACORD_QA_API35`; login, workspace, profile/audio/admin panels, favorites
  navigation and logout completed. The smoke builds and installs the Android
  debug APK. It does not start or receive a real screen stream.
  The first smoke attempt exposed a harness step that left the mobile
  navigation drawer closed; the scenario now opens it before checking favorites.
- PASS: focused analyzer over all modified Flutter implementation, widget-test
  and integration-test files (`No issues found`).
- PASS: `flutter build macos --no-pub --debug`. The build emitted two existing
  C warnings in vendored RNNoise sources and completed successfully.
- PASS: `python3 -m tools.verify.client_parity.run --base origin/master`.
- PASS: `pwsh -NoProfile -File
  tools/verify/spec_traceability/verify-spec-traceability.ps1` — 39 requirements
  referenced. The approved product brief at the Windows path in `AGENTS.md` was
  unavailable on this host; the verifier used the committed requirement index.
- PASS: `git diff --check`.
- NOT_RUN: iOS simulator runtime; no owned QA iOS simulator is configured.
- NOT_RUN: physical-device screen capture, stream media quality and paired
  sender/receiver acceptance. The Android smoke is an authenticated workspace
  journey, not media evidence.

The acceptance report is
`.out/local-features/20261029-091822/index.html`. Its machine status is
`REVIEW_REQUIRED` because it contains 177 screenshots from the six selected
overlapping feature groups and marks the entire gallery visual review as
`NOT_RUN`.

## Focused visual review

Inspected the changed component captures at their original resolutions:

- `flutter-participant-cards-stream-and-voice.png`, 800×620: the stream and
  voice-only cards are equal size; the preview is 16:9, the play affordance is
  centered, and the live/profile labels remain legible. Both footers align the
  avatar, left-aligned name and microphone status.
- `flutter-participant-cards-mobile-large-text.png`, 320×520: the voice status
  stacks cleanly at 200% text scale and remains inside the card without
  overflow.

The card capture uses a synthetic JPEG to verify rendering and sizing. It does
not represent a real stream frame or prove perceptual media quality. Generated
captures and logs remain under the ignored `.out/local-features/` directory.
