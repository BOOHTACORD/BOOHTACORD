# Flutter connection recovery panel parity

Source: Web recovery panel introduced in #505 (`b22892ed`) and the current
Flutter/Web parity audit for 2026-10-14 through 2026-10-24.

## Verification

- `flutter analyze --no-pub` on the changed implementation, tests, and native
  acceptance scenario: PASS.
- Full Flutter unit/widget suite in local-feature run `20261024-163423`:
  PASS, 1,638 tests.
- Web unit suite: PASS, 1,625 tests across 488 files; production build and
  accessibility/browser suites: PASS.
- Authenticated Web real-stack journeys at 1440 px and 393 px: PASS.
- Flutter production-widget component captures: PASS.
- `python3 -m unittest tools.ci.flutter_gates.test_artifacts`: PASS, 6 tests.
- Client parity policy, JSON validation, `git diff --check`, and spec
  traceability: PASS. The approved product brief is not available on this host;
  traceability used the committed requirement index.

The final local-feature report is
`.out/local-features/20261024-163423/index.html` with machine-readable results
in `report.json`. It is `BLOCKED`: Android and iOS runtime stages could not run
because this host has no Android emulator/device and no installed iOS
simulator runtime (`adb devices -l` empty; `simctl list runtimes` empty).
These stages remain unverified; widget captures are not device acceptance.
The report's global `visual_review` remains `NOT_RUN` because the broad
selected-feature run produced 657 gallery images. The three images relevant to
the connection card were inspected individually at source resolution.

## Visual observations

- Flutter desktop capture, 320×380: all three status rows and both retry
  controls fit inside the card. Dots align with labels, actions wrap below their
  own status, and no text is clipped.
- Flutter mobile capture, 320×380: the reconnecting state keeps all labels
  readable; unavailable retry actions are visibly disabled and remain within
  the narrow card.
- Web narrow-sidebar reference, 320×720: the same independent statuses and
  retry actions fit without horizontal overflow. Flutter uses a taller native
  touch target for its actions.

The authenticated native smoke now drives the production Flutter workspace
through a voice-error state and checks that the recovery card is visible. Its
runtime result remains `BLOCKED` until Android/iOS targets are available.
No audio, media-quality, or physical accessibility claim is made.
