# Integration check: voice recovery and roster retry

Date: 2026-11-09. Source-only integration of PR #693 head
`e565420073483c7234202817eecf362cf754e844` and PR #694 head
`d85b56aad5b028ce66f9e23bda97b872c76fb166` in branch
`codex/integration-voice-recovery-roster`, merge commit
`be97f71727a6d263390ebe13c30ad93228c71760`.

- The two branches both changed `tools/verify/livekit_network_config/check.py`.
  The integration retains both source revalidations and appends a new
  source-only registry entry for the merged verifier and feature manifest.
- `python -m tools.verify.livekit_network_config.check`: PASS.
- `python -m unittest tools.verify.livekit_network_config.test_model`:
  PASS, 18 tests.
- Flutter 3.47.7 `flutter test test/voice_roster_state
  test/voice_connection_recovery_visible_test.dart --reporter expanded`:
  PASS, 24 tests. The first invocation incorrectly named a nonexistent
  `test/voice_recovery` directory and failed to load that path; it was rerun
  with the exact test file and passed.

Earlier Windows and Android real-stack checks exercised the combined product
files separately; this integration commit has not been run through the full
canonical feature gate or installed release, and no physical-device,
production, acoustic or deployment acceptance is claimed. The integration
branch is not master and no server deployment was performed.
