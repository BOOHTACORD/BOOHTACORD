# Issue 689: Android local-feature run

- Environment: owned AVD `emulator-5554`, real disposable local API and SFU,
  synthetic accounts; no physical device. Source was HEAD `72928320d` plus
  uncommitted changes and changed while the run was in progress.
- `flutter test`: 1823 passed, three skipped, zero failed. Component-capture
  tests: 639 passed, one skipped (native telemetry/Tempo opt-in), zero failed.
  The then-running gate reported
  both stages PASS because it loaded the old skip policy; these stages are
  **BLOCKED for acceptance**. The runner has since been corrected to report
  skips as BLOCKED and to detect changed source fingerprints.
- Android native smoke and issue-689 maintenance/roster socket scenario both
  passed with `mocks: false`. The latter checks guest/auth handoff, roster,
  manual reconnect and logout, without a legacy stream or polling request.
  Audio/media and physical hardware remain NOT_RUN.
- The generated report contains 314 captures and has `visual_review: NOT_RUN`.
  Three issue-689 Android runtime images were viewed at 1080×1920: the unknown
  maintenance warning and navigation labels are legible. The login form extends
  below the visible area initially; the scrolled capture exposes the version.
  Review of the other 311 captures and the final stable-source gate is NOT_RUN.
