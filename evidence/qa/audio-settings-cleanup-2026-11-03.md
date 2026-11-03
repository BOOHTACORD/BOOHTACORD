# Audio settings cleanup verification

- Date: 2026-11-03
- Base: `84a7c95365183ac6e906fac403211eecb4837e7a` (`origin/master`)
- Feature coverage: `settings`, `shell`, `voice`, `auth`, `connection_status`, `screen`
- Source identity: the completed run `20261103-150839` recorded this base and diff hash `a8520e6cd84fae2cd184eacb50eb6b2acce207701a29e1f1ab8689dc59412ac7`, matching the reviewed working tree.
- The follow-up run `20261103-152357` used `BOOHTACORD_QA_EGRESS_PLATFORM=linux/amd64` as documented in the local-feature QA README.

## Results

| Check | Result | Evidence |
|---|---|---|
| Web unit tests | PASS | `20261103-150839/web-unit.log` |
| Web production build | PASS | `20261103-150839/web-build.log` |
| Web local-feature browser suites | PASS | Accessibility, settings hierarchy, control consistency, microcopy, and all selected feature configs in `20261103-150839/report.json`; the fallback rerun also passed all selected browser stages. |
| Web real API/SFU at 1440px and 393px | PASS | `20261103-152357/web-real-stack-1440.log` and `web-real-stack-393.log`, using the documented Egress platform override. |
| Flutter full unit suite | PASS | `20261103-150839/flutter-unit.log` — 1,748 tests passed. |
| Flutter registered component captures | PASS | `20261103-150839/flutter-component-captures.log` — 591 tests passed. |
| Focused audio Flutter tests | PASS | Device check, scan notice, noise suppression, audio hierarchy, and workspace screen tests — 135 tests passed. |
| Android QA runtime | BLOCKED | The dedicated `BOOHTACORD_QA_API35` emulator was detected. The runtime build then failed in Gradle `:app:compressDebugAssets` with `No space left on device`; no app runtime result was produced. An earlier attempt also hit a Gradle temp-directory cleanup error. |
| iOS QA runtime | BLOCKED | No dedicated iOS simulator was available. |
| `git diff --check` and feature registry JSON | PASS | No whitespace errors; `tools/qa/local_features/features.json` parses successfully. |

## Visual review

Inspected source-resolution captures from `20261103-152357` and the matching-source Flutter capture run `20261103-150839`:

- Web 1440px and 1024px settings pages: devices and microphone activation sit at the top; shortcuts and common microphone processing are visible without opening an advanced disclosure; playback reset has its own full-width section; diagnostics remain collapsed.
- Flutter 390px and 1440px captures: settings use one column on the narrow layout and two columns on desktop; the device guidance and selectors fit within the visible viewport without clipping. These Flutter captures are 480px-high viewports, so they do not show the entire scrollable page.
- No visible overflow or clipped controls in the inspected captures. The automated report's overall `visual_review` remains `NOT_RUN`, because only the audio-settings captures were visually reviewed; unrelated selected-feature screenshots were not all reviewed.

No baseline was approved. The Android runtime and complete visual-review gates remain open.
