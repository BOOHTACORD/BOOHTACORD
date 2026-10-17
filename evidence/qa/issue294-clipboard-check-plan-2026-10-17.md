# Issue #294 clipboard context: follow-up acceptance plan

Date: 2026-10-17 (Europe/Istanbul). Source: branch `codex/issue-294-local-paste`.
Issue: https://github.com/Egkurilov/BOOHTACORD/issues/294
The user authorized publishing this patch and scheduling checks; this plan does not authorize
merge, release, deployment or closing the broader issue.

## Automated checks

- On opening the draft PR, the repository's normal pull_request workflow runs selected
  contracts/Flutter/Windows and other applicable jobs. Assess checks on the PR head SHA,
  not the base revision or an older successful run; skipped jobs are not passes.
- Every 30 minutes for the next 24 hours, inspect the PR, current head, CI checks and review
  status. Keep a local record of meaningful changes. Do not rerun successful local suites
  for the same code merely because the clock fired. No automatic source edits or GitHub comments.
- If a scoped local verification is needed, require a clean worktree matching the current
  PR head; run the existing fixed regression helper and focused analyzer, preserving exact
  command, head SHA, exit code and PASS/FAIL/BLOCKED/NOT_RUN. If head differs, do not reset
  or run stale code as if it were the new revision; report NOT_RUN for the untested head.
- Notify on completion, new failures, review action or a meaningful blocker change. Preserve
  the distinction between unit/component evidence and physical acceptance.

Local checkpoint: 16/16 regression, 29/29 nearest suite, analyzer0 issues,
1449 full Flutter unit passes with1 skipped,133 component passes. These do not certify native
clipboard/IME. The full local feature gate was BLOCKED by missing Android runtime.

## Physical Android and iOS acceptance — NOT_RUN

Use a dedicated test account and test device, synthetic TEXT/DM conversations and test
clipboard data only; do not inspect a personal clipboard or other users' messages.
Record device, OS, build/commit SHA, input method, exact steps, expected and actual outcome.
For both TEXT and DM:

1. Normal paste without changing editing context inserts at the selected position once.
2. While a clipboard read is pending, move selection/cursor without changing text: the late
   text result must leave the latest text and selection unchanged.
3. While pending, change the IME composing range: preserve the latest composing/text/selection.
4. While pending, type/edit text: preserve the latest draft.
5. Switch conversations while pending: no text or attachment leaks to another conversation.
6. Co-paste text plus a synthetic image, then exercise upload failure/retry: existing image
   handling and permission checks remain functional even when stale text insertion is rejected.
7. Check background/foreground, keyboard/safe-area and current native clipboard permission/error
   behavior. Never interpret widget or emulator success as a physical-device PASS.

For primary native clipboard and any supported platform fallback, record each applicable
case separately; inaccessible or non-reproducible native timing stays BLOCKED/NOT_RUN rather
than passing by analogy with the injected completer tests. This patch needs a controlled test
build to reliably hold a native read pending; mock timing alone is not physical proof.

## Completion

The patch may have green CI while physical acceptance remains NOT_RUN. Keep issue294 open
until its broader device, lifecycle and UX acceptance is satisfied. No automatic merge/deploy.
