# Issue #294: preserve editing context during delayed Flutter clipboard paste

Date: 2026-10-17. Issue: https://github.com/BOOHTACORD/BOOHTACORD/issues/294
Base: `43d0c491575f83f03d72bb7355392ce82f56d998`; branch: `codex/issue-294-local-paste`.
Backlog leaf FV2-008; dependencies FV2-007/T-040/T-041/T-050/T-051 reviewed.
Platform: macOS arm64, Flutter3.47.7/Dart3.13.5. Scope: one composer regression;
this does not close the broad issue or its physical mobile acceptance.

## Defect and change

While native clipboard or Flutter text fallback is pending, moving selection or changing IME
composition without changing text previously allowed insertion using stale TextEditingValue.
The local9B model extended the existing guard to compare current text, complete selection
and composing range to the captured value. A different current value cancels only text insertion;
unchanged context still inserts at the captured selection. This compares current values, not
a monotonic history of every intervening edit. Existing scope/generation guards, image upload,
error feedback, focus and protected API/ACL behavior remain byte-identical outside this guard.
No timer, state field, package dependency, API/contract or backlog change was introduced.

## Actual results

| Check | Status | Actual result |
|---|---|---|
| Compiling baseline regression | FAIL (expected RED) | 8 pass,8 fail; moved-selection/composing defects across TEXT/DM and native/fallback |
| Same frozen regression after model edit | PASS | 16/16; model invoked real helper in read-only phase |
| Independent nearest clipboard/composer suites | PASS | 29/29, including co-pasted image, upload failure/retry and conversation switch coverage |
| Analyzer source/new test | PASS | No issues |
| Before/after workspace capture tests | PASS | 3 profile cases each,6 image pairs identical |
| Feature-policy tests | PASS | Exit0 |
| Complete Flutter unit suite | PASS | 1449 passed,1 skipped; skipped is not a pass |
| Registered component/capture suites | PASS | 133 passed |
| Overall feature gate | BLOCKED | Android device/emulator runtime unavailable; exit1 |
| Physical Android/iOS clipboard, IME, background/foreground | NOT_RUN | Widget tests inject synthetic clipboard data |
| Actual API/SFU, native builds and physical screen readers | NOT_RUN | No claim from widget verification |

The16 regressions use2 scopes x2 clipboard paths x4 changes (selection/composing/text/unchanged).
Both injected primary reader and delayed platform fallback are controlled with completers.
Tests assert the entire latest TextEditingValue, unchanged normal paste and no error feedback;
no actual clipboard contents, production requests or user messages were accessed.

Commands from clients/flutter with pinned SDK:

```sh
flutter test --no-pub --reporter expanded test/clipboard_paste_edit_generation_test.dart
flutter test --no-pub --reporter expanded test/message_attachment_composer_test.dart test/system_clipboard_paste_test.dart test/clipboard_paste_edit_generation_test.dart
flutter analyze --no-pub lib/src/widgets/message_attachment_composer.dart test/clipboard_paste_edit_generation_test.dart
flutter test --no-pub --reporter expanded test/workspace_screen_test.dart --plain-name 'captures production Flutter text workspace'
```

Feature command from repository root:

```sh
python -m tools.qa.local_features.run --feature chat --platform android --base 43d0c491575f83f03d72bb7355392ce82f56d998 --real-stack
```

This is check.sh's underlying module invoked with a pinned SDK PATH; the shell wrapper
prepends Homebrew and would select a different user SDK. Report:
`.out/local-features/20261017-211348/`; overall BLOCKED. Android-only --real-stack did not
start Web/API/SFU. No contracts/backlog requirements changed; contract/spec checks NOT_RUN.

## Visual review

Six TEXT/DM image pairs were byte-identical. Original PNGs requested from the viewer:
2880x1800 desktop and1179x2556 mobile at normal/2x text (viewer display may scale them).
Headers, message regions and composer geometry are unchanged; large-text wrapping stays
within the existing layout and no new action overlap was observed. These static captures
are not proof of the clipboard race fix; the asynchronous regressions provide that evidence.
Unrelated incidental full-suite captures were not reviewed; aggregate visual gate NOT_RUN.
No screenshot baseline was changed or approved. Hashes retained in external local report.

## Local model, review and authorship

Inference: Qwen3.5-9B Q4_K_M, model `boohtacord-daily-code-16k`, context16384/output4096,
digest `e9f1f098d53f65ecb7e6fa1239177fe4694790df8dd8f70bb76b5a38e57a495d`.
Ollama0.40.3/OpenCode2.0.25, loopback, OS external-network denial and no cloud fallback.
All final product semantic edits were made by the local model. The operator authored tests,
registry, evidence and review; coordinating Codex contributions are separate from local inference.

First local attempt invented TextRange offsets and an invalid ternary/null repair: compilerFAIL,
operator stopped and retained failed source/patch before restoring only that failed source.
Review supplied verified Flutter SDK TextEditingValue equality semantics. The model then
chose three explicit comparisons, initially misused TextEditingController.composing, saw
actual compiler feedback, and self-repaired value.composing. Read-only rerun produced real
16/16GREEN. The operator made no semantic edits to final product code. One initial operator
harness compile mistake was corrected before genuine RED and its log retained as well.
This is local development with review and guidance, not autonomous readiness evidence.

Peak Ollama RSS across3 sessions: 6.241GiB; pressure1 throughout; max measured swap
growth 0.000GiB (existing swap present). Only one local inference session active;
model unloaded before full verification. No unsafe system settings or unrelated apps changed.
At the local validation checkpoint no publication had occurred. The user subsequently authorized
commit/push and scheduled checks. Publication targets only the isolated feature branch and
a draft PR; no merge, deployment or issue closure is authorized.
Follow-up checks: [acceptance plan](issue294-clipboard-check-plan-2026-10-17.md).
