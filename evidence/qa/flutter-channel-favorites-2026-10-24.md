# Flutter channel favorites parity — 2026-10-24

## Scope

Web already supports favorite channel shortcuts in `ChannelNavigation.vue` and persists them by deployment origin and account. Flutter now has matching scoped preferences, a Favorites section above categories, topology-ordered shortcuts, automatic pruning of removed channels, touch controls, and desktop hover/focus controls. This is tracked as FV2-058 and registered under `shell` in the local feature and client-parity maps.

## Verification

- **Focused Flutter tests: PASS.** Preference isolation and validation, persistence, stale-session protection, add/remove and restore, topology ordering and pruning, desktop hover/focus visibility, and desktop/mobile captures all pass.
- **Targeted Dart analysis: PASS.** No issues in the changed widgets, preference store, tests, or native integration scenario.
- **Flutter unit and component suites: PASS.** The local feature report `.out/local-features/20261024-153643/index.html` records `flutter-unit=PASS` and `flutter-component-captures=PASS`.
- **Web regression suites: PASS.** Web unit/build and the registered browser suites passed, including navigation density and persisted favorites.
- **Web real-stack: PASS at 1440px and 393px.** The first local-feature attempt could not build the disposable API image because this host's Docker CLI used the legacy builder. Re-running both existing `--critical --portable-proxy` journeys with the installed Buildx plugin and BuildKit enabled completed authenticated API/SFU lifecycle checks and removed owned resources.
- **Android/iOS runtime: BLOCKED.** `tools.qa.local_features.doctor` found no dedicated QA Android AVD or iOS Simulator on this host. The authenticated native favorite interaction is registered in `integration_test/local_qa_test.dart`, but a widget capture is not evidence of native runtime acceptance. The parity matrix remains `NOT_VERIFIED` for both native targets.
- **Registry checks: PASS.** Flutter visual inventory unit tests, client-parity validation, `git diff --check`, and spec traceability passed.

## Visual review

Inspected `flutter-channel-favorites-1440x900.png` and `flutter-channel-favorites-mobile-393x852.png` at source resolution. Both show the Favorites section above the category list, with matching selected channel styling and star controls. The mobile favorite action measures 48×44 logical pixels; channel labels fit without horizontal clipping. Desktop tests confirm the unfavorited star appears on hover and keyboard focus. No screenshot baseline was approved as part of this review.
