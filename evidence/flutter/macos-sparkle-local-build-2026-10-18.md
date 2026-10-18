# macOS local Sparkle bootstrap — 2026-10-18

Task: UPD-016 (native updater build integration); dependencies UPD-014 and
UPD-015 retain their existing implementation and acceptance records.
Source: working tree based on `5eb564ff3f47962e09d9a05b17e2fe311bf2bb3b`.
Host: macOS / Darwin arm64.

The reported direct `flutter run -d macos` failed because the ignored
`clients/flutter/macos/Updaters` directory had not been restored. CI and release
wrappers restored Sparkle explicitly, but the native project did not.

The Flutter Assemble dependency now prepares the existing pinned Sparkle SDK
before Runner compiles or links. The SHA-256 pin is unchanged. Cache reuse
requires the framework binary and umbrella header as well as the version
marker, so a partial SDK with a missing header is repaired.

| Check | Result | Observation |
|---|---|---|
| Regression before implementation | PASS | New missing-header repair test failed against the old binary-only cache check. |
| `python3 -m unittest tools.build.desktop_updater.test_sdk` | PASS | Three tests: initial extraction preserving framework symlinks and offline cache reuse, missing-header repair, rejection before extraction on digest mismatch. Also passed with `/usr/bin/python3`, the build-phase interpreter. |
| `plutil -lint clients/flutter/macos/Runner.xcodeproj/project.pbxproj` | PASS | Native project remains valid. |
| `flutter build macos --debug --dart-define=BOOHTACORD_MACOS_CAPTURE_ENGINE=screen_capture_kit` | PASS | Started with no Updaters directory. Xcode automatically restored Sparkle and produced `build/macos/Build/Products/Debug/BOOHTACORD.app`. No missing-header or missing-search-path error. |
| Embedded framework inspection | PASS | Sparkle.framework exists in the built app's Contents/Frameworks. |
| `/usr/bin/python3 tools/build/desktop_updater/sdk.py macos` after build | PASS | Existing SDK reused without network access in the restricted environment. |
| `bash tools/build/macos/package.test.sh` | PASS | Existing package fixture checks passed, including negative signature and version cases. |
| `git diff --check` | PASS | No whitespace errors. |
| Runtime screen capture / installed update journey | NOT_RUN | Compilation does not establish media capability or installed updater acceptance. |

The first restricted build attempt could not write Flutter's SDK cache outside
the workspace; the subsequent authorized build completed successfully.
Requirements, backlog and API contracts were not changed. No native/UI/media
acceptance gate is closed by this build repair.
