# PR #369: clipboard context integration acceptance

2026-10-17, Europe/Istanbul. Backlog leaf FV2-008; FV2-007/T-040/T-041/T-050/T-051 dependencies reviewed. Base master: `622d68fc7663ab9113d9475cf14a717dd5a27a72`.
Tested clean source: `d325f4c06559f9e8ca1ac456644d826e71a0bf81` (source hashes, commands/results and screenshot hashes in the adjacent JSON).

A delayed clipboard result must preserve the current draft when its text, complete selection or composing range differs from the captured value. Normal paste still inserts once at the selected position. The original four-line product patch remains unchanged; integration retains all current master changes. This compares current values, not a monotonic history of every edit.

The original local-model authorship and earlier RED/GREEN evidence remain in `issue294-local-clipboard-context-2026-10-17.md`. Its missing-runtime and publication-only authorization statements describe that earlier checkpoint. The user subsequently requested finishing the open PRs into master. This record supplies new native acceptance for the narrow regression; #294 remains open for its broader physical-device requirements.

| Check | Result |
|---|---|
| Nearest clipboard/composer suites | PASS, 29 tests |
| Full Flutter unit suite | PASS, 1449 passed, 1 skipped |
| Registered chat component/capture suites | PASS, 133 tests |
| Android15 API35 arm64 clipboard target | PASS, 16 cases; 17 runner tests including teardown |
| iOS27 Simulator clipboard target | PASS, 16 cases; 17 runner tests including teardown |
| Android actual API native workspace smoke | PASS, new debug build, real authentication/panels/logout |
| iOS actual API native workspace smoke | PASS, new Simulator build, real authentication/panels/logout |
| Local feature runner | 4/4 stages PASS; raw visual status REVIEW_REQUIRED |
| Focused analyzer | PASS, no issues |
| Feature-policy/native-runner unit checks | PASS, 9 tests |
| Selected source-resolution images | 16 reviewed; scoped PASS; no baseline changed |

## Native clipboard scope

`clients/flutter/integration_test/clipboard_context_qa_test.dart` runs the production composer on dedicated QA devices. It writes synthetic clipboard data and reads it through the actual rich-text plugin. A completer holds delivery after the OS read while the editing context changes. Returning null then exercises Flutter's actual platform text fallback. Two scopes × two paths × selection/composing/text/unchanged = 16 cases per platform. Reversed directional selection and affinity are included. Full `TextEditingValue` equality is asserted after completion.

The QA field is read-only so an independent live keyboard cannot overwrite the controlled composing/selection fixtures. These are native engine/OS clipboard checks, not physical typing or paste gestures. No API or SFU is used in this small editor fixture; separate authenticated native smoke uses the disposable Go/PostgreSQL/LiveKit stack. Its media result remains NOT_RUN.

An initial Android fixture run failed: live IME rewrote controlled editing values and Android screenshot preparation was incorrectly reused across test resets. It also used unintended installed Flutter3.47.6. The corrected fixture uses per-test surface conversion, a read-only controlled field and pinned Flutter3.47.7/Dart3.13.5; Android and iOS both passed. Failed logs are retained privately and hashed in JSON; this was not a product-code failure or a successful first attempt.

## Commands and visual observations

From `clients/flutter`, with pinned Flutter3.47.7 PATH, Android SDK/JDK17 and `BOOHTACORD_NATIVE_CAPTURE_DIR` pointing to the private result directory:

```sh
flutter test --no-pub --reporter expanded test/clipboard_paste_edit_generation_test.dart test/message_attachment_composer_test.dart test/system_clipboard_paste_test.dart
flutter drive --no-pub --driver test_driver/local_qa.dart --target integration_test/clipboard_context_qa_test.dart -d emulator-5554
flutter drive --no-pub --driver test_driver/local_qa.dart --target integration_test/clipboard_context_qa_test.dart -d 82C26E13-0F1F-43F9-AF27-866DC22C2456
flutter analyze --no-pub lib/src/widgets/message_attachment_composer.dart test/clipboard_paste_edit_generation_test.dart integration_test/clipboard_context_qa_test.dart
```

From the repository root, using check.sh's underlying module to preserve the pinned SDK PATH and isolated Docker configuration:

```sh
python3 -m tools.qa.local_features.run --feature chat --platform android --platform ios --base 622d68fc7663ab9113d9475cf14a717dd5a27a72 --real-stack
python3 -m unittest tools.qa.local_features.test_policy tools.qa.local_features.test_native
```

Result directory: `.out/local-features/20261017-224823`. Eight native editor captures (1080×2400 Android, 1206×2622 iOS) show the preserved draft or expected normal insertion without error feedback. Six actual production TEXT/DM component captures (1179×2556 normal/large text, 2880×1800 desktop) keep the header, message area and composer visible; large text wraps inside the field and actions do not overlap it. Two actual authenticated native workspace captures show the empty channel selection without an error overlay. All sixteen were opened at original resolution. Native empty-workspace screenshots do not prove chat behavior. Incidental admin/settings/screen-share images are outside this clipboard-only review, so the raw aggregate report stays REVIEW_REQUIRED. No screenshot reference was approved.

Physical Android/iOS clipboard gestures, real IME input, physical lifecycle/screen readers and media quality remain NOT_RUN. This patch does not close those gates or issue #294. No release, deployment, credentials change or Keychain interaction was performed. Requirements, backlog and wire contracts have no new delta versus master. CI on the exact published head is checked separately before merge and linked in the PR metadata/final receipt.
