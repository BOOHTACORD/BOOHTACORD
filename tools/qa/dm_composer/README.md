# Issue294 DM/composer actual-runtime acceptance

Selected leaf FV2-019 (dependencies FV2-001/FV2-007/FV2-017/T-041/T-050/T-051); composer scope also follows FV2-008/T-041. Existing nearest Flutter search regressions exercise DM result/context/back and resize.

Run only in the coordinated QA worktree. Request the shared Flutter SDK build lease before any Flutter command. Android is exclusively emulator-5556 / BOOHTACORD_QA_283_API35; iOS is82C26E13-0F1F-43F9-AF27-866DC22C2456. Do not reuse another worker's devices, ports, credentials or captures.

Owned services: HTTPS4940, API4943, Tempo4942, SFU4992/4993/4994. Android lifecycle control is authenticated loopback4944 and dispatches HOME then launches only the QA294 package.

The build runner snapshots src/public/config/contracts before production compilation into a private temporary copy (no .env files); its receipt pins the actual source and immutable dist. The Web runner validates that receipt and uses the immutable production Web build at `.out/qa294-build`. PUBLIC_ORIGIN in that build affects social-preview metadata only; DM/search requests use the actual current4940 origin. Pin both Web source/build manifests in receipts. Do not rebuild a shared dist during another worker's build lease.

Before native execution copy `clients/flutter/` into `/private/tmp/boohtacord-qa294-flutter`, excluding only anchored `/build`, `/.dart_tool`, `/ios/Pods`, `/ios/.symlinks`. Change the private Android applicationId and private iOS bundle identifiers from ru.boohtacord.app to ru.boohtacord.qa294; preserve Android namespace/activity. Product lib, target and driver must match the checkout exactly. Run pubget and scoped analysis in this private copy. No SDK/app binary/private defines are committed.

Commands from the repository root:

```
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest tools.qa.dm_composer.test_contracts
PYTHONDONTWRITEBYTECODE=1 python3 -m tools.qa.dm_composer.build
PYTHONDONTWRITEBYTECODE=1 python3 -m tools.qa.dm_composer.run
PYTHONDONTWRITEBYTECODE=1 python3 -m tools.qa.dm_composer.run_native --platform android
PYTHONDONTWRITEBYTECODE=1 python3 -m tools.qa.dm_composer.run_native --platform ios
```

Nearest pre-runtime check: `flutter test --no-pub test/workspace_screen_test.dart --plain-name search` in the private copy. Product fixes require a focused RED behaviour regression before implementation and the shared local-feature mandatory check afterward.

Each attempt first archives earlier captures/receipts. Required rows, successful native process and fresh screenshots are required for observed PASS. Full issue remains PARTIAL without physical touch/IME/image-picker/clipboard gesture, physical background/foreground and real-user timing. Native Clipboard platform calls plus controlled paste are distinct from a physical paste gesture. Android HOME/resume proves emulator OS dispatch and actual Flutter lifecycle observer; iOS OS lifecycle remains NOT_RUN unless separately executed. Flutter viewport resize is controlled engine geometry, not OS rotation. No media capacity/audio quality is claimed.

Synthetic fixed fixture text is used only in the disposable owned database and ignored local captures. Public reports contain checks/counters/statuses and source/artifact/capture hashes, no session/control credentials, account/DM IDs or message payloads. Inspect PNGs at original resolution before reporting visual observations. After hashes are recorded, remove own installed QA apps, private compiled credential-bearing builds/defines/raw logs, owned reverses/services and shut down assigned devices. Retain sanitized local PNG/JSON receipts. Do not close a physical gate from emulator evidence.
