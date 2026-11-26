# FE-55 Web DM clipboard implementation plan

**Goal:** Complete DM image paste with real clipboard, scoped retry/cancellation and participant-only ACL acceptance.
**Architecture:** Preserve existing DM composer, shared queue and API/ACL. Coalesce scope/reset watchers in both native picker bindings so an early clear cannot overwrite restored ready attachments. Move the bounded DM upload client into `direct_message/attachment_upload/client.ts` and retain its old export as a forwarding edge. Preserve diagnostic text; add typed status/code for the existing storage explanation. Extend only the populated-queue editor width rule to DM if the geometry baseline fails.
**Tech Stack:** Vue/Pinia, Vitest, Playwright/Edge, trusted Xvfb clipboard, owned Go/PostgreSQL/HTTPS UploadStack.
**Execution:** Inline, per user authorization; delivery receipt is the PR after exact-head CI and merge verification.

## 1. Preserve and expose failures

- [x] Add `clients/web/src/direct_message/attachment_upload/client.spec.ts` importing the existing upload export initially. Verify real507 status/code reaches the queue, failed File identity and blocked Send survive, explicit retry succeeds, unknown diagnostics remain unchanged, inclusive25MB and oversized rejection hold.
```ts
await expect(uploadDirectMessageAttachment('dm-a', file, request)).rejects.toMatchObject({ status: 507, code: 'INSUFFICIENT_STORAGE' })
expect(queue.error.value).toBe('Недостаточно места на сервере. Повторите загрузку, когда место освободится.')
```
- [x] Add `clients/web/tests/dm_clipboard/fixture.{html,ts}` and `helpers.ts`, with the actual DM component and independent scoped state. Add `tests/accessibility/dm_clipboard_paste.browser.spec.ts`: six width/text-scale cases,507/retry, pending A/B switch and limits. Reuse synthetic paste by an optional selector in `tests/clipboard_paste/helpers.ts`.
- [x] Run nearest Vitest and Windows Edge cases on the unchanged production code; preserve failing results and original-resolution captures.

## 2. Bounded implementation

- [x] Move upload implementation to the child leaf; adjust relative imports and `DirectMessageAttachmentPicker.vue`; old path forwards. Keep the existing six attachment API tests as the preservation baseline. New unit test imports the native child after the move.
```ts
throw Object.assign(new Error(`Не удалось загрузить вложение (${response.status}${code}).`), {
  status: response.status, code: typeof error.code === 'string' ? error.code : undefined,
})
```
- [x] Baseline proved all six layouts visible; preserve CSS. Conditional implementation was not needed: extend `conversation/upload_queue/text_layout.css` to `.direct-message-conversation .message-composer:has(.upload-queue) > textarea` using the existing `min-width: min(8rem, 100%)`. No empty-composer or other UI change.
- [x] Repeat nearest tests and inspect all focused screenshots at source resolution.

- [x] Stronger ready-file return test failed for both TEXT and DM. Replace the two independent picker watchers with one batched native binding:
```ts
watch([() => props.directMessageId, () => props.clearToken], ([id], [previous]) => {
  if (id === previous) clear()
  else restore(props.initialAttachments ?? [])
})
```
- [x] Run both original/failing scope cases and the complete21 TEXT/DM browser cases; all pass. Verify ready attachment restoration in the real retry journey too.

## 3. Real clipboard and ACL

- [x] Add `tools/qa/dm_clipboard/{run.py,fixture.mjs,access.mjs,scenario.mjs}` on the owned UploadStack. Parameterize existing clipboard `paste/capture/send` helpers with their unchanged TEXT default selector. Register synthetic members and two DMs; use actual trusted Ctrl+V at1440/393, mixed/plaintext, explicit attachment-only send, original hashes and independent drafts.
- [x] Cause real507 using two held channel reservations, release and retry the retained image after changing OS clipboard. Abort a throttled DM upload on scope change and require zero leaked reservations. Record actual admission; do not infer partial-server cancellation from admission0.
- [x] Verify participant download/preview and denial of history/search/original/preview/upload to a third member and a nonparticipant administrator. Reject cross-DM attachment IDs. Use current contracts; no token or DM body logging.
- [x] Run the existing TEXT clipboard journey after generic helper parameterization to preserve FE-54.

## 4. Acceptance and delivery

- [x] Register FE-55 in backlog/task evidence, chat registry/parity and the native component catalog. Add source-bound `evidence/qa/web-dm-clipboard-2026-11-26.md`; preserve historical QA-21/FE-54 evidence.
- [ ] Run Web units/build, focused Edge cases, native contracts, traceability, generators/parity/ownership, and `./tools/qa/local_features/check.sh --feature chat --feature support --feature auth --feature connection_status --feature idle_afk --feature screen --feature voice --platform web --base 57bed06e68d26fa835d25bd0c612c69e28631efa --real-stack`. Retain any unrelated FAIL/BLOCKED; close only applicable verified gates.
- [ ] Inspect status/file sizes and exact staged paths; require fresh explicit preflight COMMIT_ALLOWED. Push a semantic branch/PR, wait exact-head required CI, merge, fetch master and verify tested-tree equality, ancestry and FE-55 completion. Record the final receipt in the PR.
