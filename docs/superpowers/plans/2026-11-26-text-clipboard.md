# TEXT clipboard completion implementation plan

**Goal:** Complete FE-54 with real clipboard, scoped cancellation, disk-full retry and protected attachment delivery.
**Architecture:** Preserve clipboard extraction, synchronous plain-text insertion and the shared managed upload queue. Localize only the known507/INSUFFICIENT_STORAGE failure; retain files for explicit retry and preserve unknown errors. Native Flutter and FE-55 remain separate.
**Tech Stack:** Vue/Pinia, Vitest, Playwright, owned PostgreSQL/Go/HTTPS and capacity-bounded UploadStack.

## 1. Behavior baseline

- [x] Keep the existing three clipboard behavior cases; replace source-string assertions with real browser coverage in `clients/web/tests/accessibility/clipboard_paste.browser.spec.ts` and its `tests/clipboard_paste/` fixture.
- [x] Verify mixed paste at a selection, no automatic send, pending scope switch, failed retry, ten-file/25MB limits and ordinary text.
- [x] Add `clients/web/src/conversation/upload_queue/failure.spec.ts` before production edits:
```ts
const cause = { status: 507, code: 'INSUFFICIENT_STORAGE' }
// Failed file remains queued, prepared IDs stay empty, send stays blocked.
expect(queue.items.value[0]?.error).toBe('Недостаточно места на сервере. Повторите загрузку, когда место освободится.')
```
- [x] Run focused unit/browser cases on the original implementation; retain the actual failing result.

## 2. Bounded failure presentation

- [x] Add `upload_queue/failure.ts`, shared by queue global and per-item errors:
```ts
if (typeof cause === 'object' && cause !== null && 'status' in cause && cause.status === 507 &&
    'code' in cause && cause.code === 'INSUFFICIENT_STORAGE') return storageFullMessage
return cause instanceof Error ? cause.message : 'Не удалось загрузить вложение.'
```
- [x] Re-run the same cases; preserve existing extraction, upload identities, ACL and other failure messages.

## 3. Narrow editor regression found by visual review

- [x] Test the editor's nonzero width, visible hit area and full-line height after image paste at320/393/1440px and100/200% text. Original narrow layouts fail4 cases: textarea has zero width despite a nonempty value.
- [x] Add `upload_queue/text_layout.css`, imported by `src/style.css`, scoped only to TEXT with a populated upload queue:
```css
.text-conversation .message-composer:has(.upload-queue) > textarea { min-width: min(8rem, 100%); }
```
- [x] Re-run the same six layout cases and real clipboard journey; inspect captures before closing FE-54.

## 4. Real acceptance and delivery

- [x] Add `tools/qa/clipboard_paste/` using the existing owned UploadStack. Use a private Xvfb clipboard and trusted Ctrl+V. Hold two real reservations to cause507, release them and retry the same file. Test both widths, co-pasted text, explicit send, scope cancellation and protected original bytes.
- [x] Register FE-54 in backlog/task evidence and chat acceptance/parity; run native contracts, traceability, required Web feature acceptance, build and preflight. Inspect original-resolution captures; keep unrelated failures/skips explicit.
- [ ] Push and merge only after exact-head green CI; verify master contains the tested tree. Final CI/merge receipt is recorded in the PR.
