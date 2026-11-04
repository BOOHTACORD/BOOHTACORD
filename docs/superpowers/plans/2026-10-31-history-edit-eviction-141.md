# History edit retention across cache eviction — implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. The human already delegated inline execution; do not ask an execution-choice question or create another agent.

**Goal:** Preserve all opened TEXT editor states and the focused editor DOM across virtualization and reversible eviction, with at most500 active states and unchanged contiguous500-message cache/authenticated scope.

**Architecture:** A TEXT-only provider retains at most500 active editor controllers and numeric selection snapshots, releasing slots on save/cancel and fencing every scope generation. Virtual rendering keeps only one focused/active keyed DOM pin; other open editors resume controller state after remount without adding hidden rows. Scope reset wipes retained state and remounts visible editors; server message cache, cursors and ACL stay unchanged.

**Tech stack:** Vue 3.5.43, Pinia 4.0.3, TypeScript 5.9.3, Vitest 5.0.1, Playwright 1.63.0, Node 24.18.0; real Go/PostgreSQL 17.6 acceptance is independently owned by root.

## Operating brief and gates

- Classification: `small_direct`, medium task, native structure routing.
- Branch: `codex/fix-history-edit-eviction-141`; base `46e83f7655fb75c5acb29c91a439db551598cb40`.
- Leaf: `clients/web/src/conversation/history_window` editing-pin lifetime. Native edge: `TextHistoryList.vue` → `use_text_history_list.ts` → `use.ts`; `MessageItem.vue` → `message_edit_controller.ts` stays unchanged.
- Backlog: T-040 (T-010/T-020), T-050; requirement acceptance belongs to original GitHub #141. No backlog/contract changes are planned.
- Ratchet: target100/hard120 source lines; target8/hard16 production files and direct tests. Split retention into a bounded helper rather than expanding the virtualizer beyond hard120.
- DirectMessageHistoryList uses its own full list/scroll-anchor implementation, not `useHistoryWindow`; leave it unchanged. Shared numeric draft-epoch API remains unchanged.
- Production edits are HOLD until root supplies a qualified fresh built-browser baseline and approves this design. Plan and failing tests may be written first. Root already approved the single retained pin and reactive internal draft epoch; no user permission is needed.
- Merge/closure HOLD until independent actual built-Web acceptance, cleanup and exact-source required CI pass. Refs #141 only, no automatic closure text.
- Preserve all dated FAIL/UNKNOWN receipts, old20-dataset evidence and #587 fix. A historical performance profile stays dated; no fresh latency, INP, physical-media or production-SLO claim follows from source tests.

## Exact files

Production:
1. Create `clients/web/src/conversation/history_window/editing_pin.ts`: bounded row lifetime and closing-focus restoration.
2. Modify `clients/web/src/conversation/history_window/use.ts`: use the retained row only outside rowIndex; preserve normal window/geometry behavior.
3. Modify `clients/web/src/conversation/history_window/window.ts`: optional `detached` render marker only.
4. Modify `clients/web/src/conversation/history_window/use_text_history_list.ts`: synchronous scope/reset binding.
5. Modify `clients/web/src/conversation/TextHistoryList.vue`: scoped MessageItem key.
6. Modify `clients/web/src/conversation/draft_memory.ts`: reactive internal epoch, same public numeric API.

Tests/support:
1. `clients/web/src/conversation/history_window/editing_pin.spec.ts`.
2. `clients/web/src/conversation/draft_epoch.spec.ts`.
3. `clients/web/tests/chat_rhythm/history_edit.html`.
4. `clients/web/tests/chat_rhythm/history_edit.ts`.
5. `clients/web/tests/chat_rhythm/history_edit_data.ts`.
6. `clients/web/tests/chat_rhythm/history_edit_helpers.ts`.
7. `clients/web/tests/chat_rhythm/history_edit_eviction.browser.spec.ts`.
8. `clients/web/tests/chat_rhythm/history_edit_privacy.browser.spec.ts`.
9. `clients/web/tests/chat_rhythm/history_edit_state.browser.spec.ts`.

Metadata: `tools/qa/local_features/features.json`, this plan and `evidence/qa/issue141-history-edit-retention-2026-10-31.json`. Keep every existing platform decision/scope; append the exact Web scenario and refresh required fingerprints.

## Task 1 — retain meaningful browser RED before production changes

- [ ] Add a synthetic production-component fixture under the already required `tests/chat_rhythm/playwright.config.ts` profile. It mounts actual TextHistoryList, author directory and message store. Its normal requests are intercepted only inside this component fixture; root's independent real-API acceptance has no substituted business responses.
- [ ] Generate 1000 immutable messages with monotonically increasing timestamps, UUIDs, own author, revision1 and an explicit mention. Return the latest500 (or450 for a positive control); before pages contain50 older messages, after pages20 newer messages. Record PATCH bodies and simulate409/current revision refresh only in the state test.

Data module content:

```ts
export const uid = (n: number) => `10000000-0000-4000-8000-${String(n).padStart(12, '0')}`
export const own = uid(1), peer = uid(2), channelA = uid(3), channelB = uid(4)
export function wire(index: number, channel = channelA, revision = 1) {
  return { id: uid(1000 + index), channel_id: channel, author_id: own,
    client_message_id: uid(3000 + index), body: `History fixture ${index}`,
    revision, deleted: false, attachments: [], mention_user_ids: [peer],
    created_at: new Date(Date.UTC(2026, 9, 31, 0, 0, index)).toISOString() }
}
export function page(before: string | null, after: string | null, count: number, channel = channelA) {
  const index = (id: string) => Number(id.slice(-12)) - 1000
  const high = before ? index(before) - 1 : after ? Math.min(999, index(after) + 20) : 999
  const low = before ? Math.max(0, high - 49) : after ? index(after) + 1 : 1000 - count
  return { messages: Array.from({ length: Math.max(0, high - low + 1) }, (_, i) => wire(high - i, channel)),
    ...(before || !after ? low > 0 ? { next_cursor: uid(1000 + low) } : {} : high < 999 ? { next_cursor: uid(1000 + high) } : {}) }
}
```

- [ ] Fixture controls use normal `store.open`/`loadOlder`/`loadNewer`; account/channel changes are reactive props. Reset and clearDraftMemory controls are separate. Add a mounted `useSavedComposer` child for late callback/onUnmount cleanup checks, without modifying that controller.
- [ ] Use actual editor actions: open the message menu, click Изменить, fill a synthetic unsaved value, set a nonempty caret range and keep a DOM reference. Scroll to the old edge, focus/click the existing older button, load actual fixture pages and restore with three newer clicks.

Primary regression content (three independently initialized repetitions):

```ts
for (const repeat of [1, 2, 3]) test(`retains exact active editor through eviction ${repeat}`, async ({ page }) => {
  await setup(page)
  const editor = await begin(page, 999)
  await editor.fill('Uncommitted fixture draft')
  await editor.evaluate((element) => { const input = element as HTMLTextAreaElement
    input.setSelectionRange(4, 12); Object.assign(window, { retainedEditor: input }) })
  await older(page)
  await expect(editor).toHaveCount(1)
  await expect.poll(() => cacheSize(page)).toBe(500)
  await expect.poll(() => cacheHas(page, 999)).toBe(false)
  const bounds = await geometry(page)
  expect(bounds.rows).toBeLessThan(64)
  expect(bounds.detached).toBe(1)
  expect(bounds.scrollWidth).toBeLessThanOrEqual(bounds.clientWidth + 1)
  for (let i = 0; i < 3; i++) await newer(page)
  await expect(editor).toHaveValue('Uncommitted fixture draft')
  expect(await editor.evaluate((element) => element === (window as any).retainedEditor)).toBe(true)
  expect(await editor.evaluate((element) => [(element as HTMLTextAreaElement).selectionStart, (element as HTMLTextAreaElement).selectionEnd])).toEqual([4, 12])
  await expect.poll(() => cacheHas(page, 999)).toBe(true)
})
```

- [ ] Run the three regressions and both controls on untouched46e:450→500 without eviction, and500 with editing row700 retained inside the next window. Keep native test output and fixture/runner/source hashes. Expected old source: three semantic eviction failures, both controls PASS. Missing import/setup failure is not an accepted RED.
- [ ] Add oldest-edge test: page backwards until indices0..499, edit0, load newer (evicts0), then older (restores0). Check exact editor reference/text/caret and contiguous cache<=500.

## Task 2 — focused unit regressions and minimal source patch after root baseline GO

- [ ] Add helper tests for row absent→same key restored, same-row server revision update, single-pin replacement, wrong-id cancel, explicit reset and empty-row policy. A removed-retention mutation must fail the retained browser regressions while both controls stay PASS.
- [ ] Add an epoch test using `watch(() => draftMemoryEpoch(), ..., { flush: 'sync' })`: clear increments exactly once synchronously; getters remain numeric; revision and crosschannel/account draft tests stay unchanged.
- [ ] After root baseline GO, implement helper with this interface and bounded behavior:

```ts
import { nextTick, onScopeDispose, shallowRef, watch, type ComputedRef, type Ref } from 'vue'
import type { HistoryRow } from './window'

export function useEditingPin<T extends HistoryRow>(rows: ComputedRef<T[]>, root: Ref<HTMLOListElement | null>) {
  const row = shallowRef<T>()
  const clear = () => { row.value = undefined }
  onScopeDispose(clear)
  watch(rows, (current) => {
    if (!row.value?.messageId) return
    const latest = current.find((item) => item.messageId === row.value?.messageId)
    if (latest) row.value = latest
  }, { flush: 'sync' })
  function setEditing(messageId: string, editing: boolean): void {
    const detached = row.value?.messageId === messageId && !rows.value.some((item) => item.messageId === messageId)
    const element = detached ? [...(root.value?.querySelectorAll<HTMLElement>('[data-message-id]') ?? [])]
      .find((item) => item.dataset.messageId === messageId) : undefined
    const restoreFocus = !editing && Boolean(element?.contains(document.activeElement))
    if (editing) row.value = rows.value.find((item) => item.messageId === messageId)
    else if (row.value?.messageId === messageId) clear()
    if (restoreFocus) void nextTick(() => {
      if (document.activeElement !== document.body) return
      root.value?.querySelector<HTMLElement>('[data-history-control] button:not(:disabled), .message-row')?.focus()
    })
  }
  return { row, setEditing, clear }
}
```

- [ ] In `window.ts`, change only RenderedRow's type extension to `{ index: number; pinned: boolean; detached?: boolean }`.
- [ ] In `use.ts`, import `useEditingPin`, keep `focusedMessage` and replace `editingMessage` with `const editingPin = useEditingPin(rows, root)`. Use the following render logic; the normal row slice/range/sort stays identical:

```ts
const pin = editingPin.row.value
const pinIndex = rowIndex.value.get(pin?.messageId ?? focusedMessage.value ?? '')
if (pinIndex !== undefined && (pinIndex < current.start || pinIndex >= current.end)) output.push({ ...rows.value[pinIndex]!, index: pinIndex, pinned: true })
else if (pin && pinIndex === undefined) output.push({ ...pin, index: -1, pinned: true, detached: true })
```

- [ ] For detached only, return `{ position: 'absolute', top: '0', left: '0', width: '1px', height: '1px', overflow: 'hidden', clipPath: 'inset(50%)' }` from rowStyle. Do not set hidden/display:none/visibility/inert/aria-hidden. The row is outside layout and does not extend scrollHeight or overlap visible rows; it retains its existing focusable DOM. Test these assertions in the real browser.
- [ ] Export `setEditing: editingPin.setEditing` and `clearPins` (clears editingPin and focusedMessage). Keep focusedMessage's existing absent-row reset; remove only editingMessage's absent-row reset. Ignore a ResizeObserver size only when its message key is absent from current rowsByKey (`key && row && height > 0`), so the clipped retained row never becomes a measured normal timeline height. Do not change the observer lifecycle or general geometry algorithms.
- [ ] `draft_memory.ts`: add `import { ref } from 'vue'`, replace `let epoch = 0` with `const epoch = ref(0)`, return `epoch.value` from the getter and increment `epoch.value` in clear. All other draft code remains verbatim.
- [ ] In use_text_history_list add this exact scope binding and return historyScope:

```ts
import { draftMemoryEpoch } from '../draft_memory'
const historyScope = computed(() => JSON.stringify([props.channelId, store.channelId, props.session?.accountId ?? null, draftMemoryEpoch()]))
watch([historyScope, () => store.messages.length === 0], () => historyWindow.clearPins(), { flush: 'sync' })
```

- [ ] TextHistoryList destructures historyScope and adds `:key="`${historyScope}:${entry.key}`"` to MessageItem only. Changing scope destroys visible editors as well as detached editors; the list root itself is preserved for observer/geometry stability. No MessageItem/controller edit.

## Task 3 — controller state, closing-focus and privacy browser coverage

- [ ] For each reset trigger (account, channel, store.channelId/reset, empty messages, clearDraftMemory), test visible and detached editors separately. Change back to the original account/channel and reload the same row: editor/draft must not reappear. Explicit clearDraftMemory followed by same-account remount must also remain clean.
- [ ] Existing saved-composer fixture: type channelA draft, switch toB/type independent draft, returnA/exact restore, clearDraftMemory, run a delayed callback modifying old composer then unmount it. `loadDraft` must stay null; the old epoch cannot resurrect private state. Existing revision tests still pass.
- [ ] Trigger409 before eviction, then roundtrip: same controller must show conflict and preserve draft, mentions and expected revision1. Normal RefreshVersion obtains revision2 without overwriting the draft; Save PATCH sends expected_revision2 and unchanged mention IDs. A deleted refresh keeps the existing copy notice and does not permit overwrite.
- [ ] Keep an edit PATCH pending through eviction and return. Save remains disabled/duplicate-protected; resolving the owned request changes only that editor. Original useMessageEditController unit tests remain mandatory and unmodified.
- [ ] Close a detached editor with the existing keyboard submit/cancel path. If focus was inside that closing editor, move it to a meaningful existing history control/row after removal. If focus was already on a load button or outside the editor, leave it untouched. No automatic save/cancel/delete is introduced.
- [ ] Capture restored editor, detached geometry/reading anchor, conflict and privacy reset at1440 and393 with source-sized PNGs. Review original pixels and record observations; these are production-component fixtures, separate from root's built-Web/real-API acceptance. Preserve ResizeObserver warnings as observations; do not widen this fix.

## Task 4 — registered native checks and canonical real-stack gate

- [ ] Register acceptance `issue141` in chat with exact browser tests, unit tests, source scope and limits. The existing chat_rhythm profile discovers the new `*.browser.spec.ts` files automatically; prove discovery in the actual output. Preserve all Android/iOS/platform decisions and prior scopes. Run actual parity/policy verifiers before describing them as PASS.
- [ ] Execute from `clients/web` with Node24.18.0:

```sh
npm test -- --run src/conversation/history_window src/conversation/message_edit_controller.spec.ts src/conversation/edit_conflict_recovery.spec.ts src/conversation/draft_memory.spec.ts src/conversation/draft_epoch.spec.ts
npx playwright test -c tests/chat_rhythm/playwright.config.ts --grep 'history edit'
npm test
VITE_PUBLIC_ORIGIN=https://example.invalid npm run build
```

- [ ] Run the registered canonical gate on exact frozen source (Web platform only; selected feature coverage must be complete, not arbitrarily relaxed):

```sh
./tools/qa/local_features/check.sh --feature chat --feature auth --feature connection_status --feature screen --feature voice --platform web --base 46e83f7655fb75c5acb29c91a439db551598cb40 --real-stack
```

If coverage reports additional mandatory features, add their existing selection rather than weakening coverage. Keep missing runtime dependencies as BLOCKED until installed/cached in the owned QA scope; no global Docker settings or old services changes. Review every generated selected screenshot at source resolution.

- [ ] Mutation: temporarily disable only retained fallback/reset behavior in an isolated overlay/copy, run the same three eviction regressions and two positive controls, retain semantic FAIL/PASS output, restore exact production bytes and verify all source hashes. Do not call a setup failure a successful mutation.
- [ ] Inspect explicit status and file sizes; stage only listed source/tests/registry/plan/evidence. No .out, raw private data, media, node_modules or generated registrants. Commit immutable source and send full SHA/tree/source fingerprints to root before its fixed runtime starts; thereafter no source edits without a new freeze.

## Task 5 — independent acceptance, CI and closure

- [ ] Root replays the fresh baseline/fixed built-Web real-API cases: eviction/restoration and two positive controls, both paging directions, anchor/focus, reply/edit/delete/tombstone/images, channel/account/logout/same-account relogin and bounded server cache. Root decides exact unchanged-facet reuse against dated performance/index/context evidence. Preserve normal API ACL/security behavior and #587 realtime regression.
- [ ] Create Refs-only PR on the frozen source; dispatch the existing full exact-head hosted workflow if normal routes legitimately skip required platforms. Require actual PG17.6, Android and macOS results plus current relevant browser/native/security contracts; report skips honestly. Retain failures and test/source hashes.
- [ ] After root's all-original-criteria verdict and owned cleanup PASS, refresh current head/base/checks, merge only the exact tested tree. Publish safe immutable protects→actual argv→platform→mandatory trigger→concrete result+hash rows and original12 issue checkboxes without weakening wording. Parent gates/43 decisions remain unchanged.
- [ ] Observe the existing automatic delivery; verify retained receipt ZIP digest, producer binding, fresh source/health/migration inventory/volumes and public Web receipt. No manual production fault/load/operations. Close #141 only after actual acceptance and merge evidence; CI alone does not close it.

## Stop conditions and unresolved observations

- Before root baseline GO: no production edits.
- Before final runtime/cleanup/CI: no merge/closure.
- A state/geometry/privacy regression is a real blocker; no source-test proxy for browser acceptance.
- Historical dev ResizeObserver-loop warnings have UNKNOWN cause/production impact and are retained, not silently fixed or promoted to a production defect.
- Physical Android/iOS/media, broad parent QA and production SLO/capacity remain separate NOT_RUN/BLOCKED gates.

## Approved detached keyboard binding

Root approved a detached-only tabindex binding. Append this exact code to editing_pin.ts and import `type Directive` from Vue; TextHistoryList imports `vRetainedEditingPin` and places `v-retained-editing-pin="Boolean(entry.detached)"` on its existing v-for li. It does not blur the active element or introduce hidden/inert/ARIA hiding. Removed descendants are restored and released on every update; reattachment and unmount restore exact original presence/value, so metadata is bounded by the current one retained subtree.

```ts
const originalTabStops = new WeakMap<HTMLElement, Map<HTMLElement, string | null>>()
function bindTabStops(element: HTMLElement, detached: boolean): void {
  const saved = originalTabStops.get(element) ?? new Map<HTMLElement, string | null>()
  for (const [target, value] of saved) if (!detached || !element.contains(target)) {
    if (value === null) target.removeAttribute('tabindex')
    else target.setAttribute('tabindex', value)
    saved.delete(target)
  }
  if (!detached) { originalTabStops.delete(element); return }
  for (const target of element.querySelectorAll<HTMLElement>('button, [href], input, select, textarea, [tabindex], summary')) {
    if (!saved.has(target)) saved.set(target, target.getAttribute('tabindex'))
    target.setAttribute('tabindex', '-1')
  }
  originalTabStops.set(element, saved)
}
export const vRetainedEditingPin: Directive<HTMLElement, boolean> = {
  mounted: (element, binding) => bindTabStops(element, binding.value),
  updated: (element, binding) => bindTabStops(element, binding.value),
  beforeUnmount: (element) => bindTabStops(element, false),
}
```

Actual baseline test preparation result: native21PASS plus the new synchronous epoch expectation1semanticFAIL; corrected component-browser3evictionFAIL/2positive-controlsPASS, no skips. Initial fixture style/desktop-menu-locator setup failures are retained separately and are not product evidence. Production remains untouched pending root actual built-AppShell/API baseline.

## Exact retained test implementation

The following contents are the executable fixture/unit/browser plan. The normal component fixture uses controlled API responses; root owns separate real-built-AppShell/API acceptance. Registry path selection was actually checked with the project policy: features.json selects auth/connection_status/screen/voice, and changed history source selects chat. Therefore all five selected features above are required for this metadata change. No selector or skip is relaxed.

### clients/web/src/conversation/history_window/editing_pin.spec.ts

```ts
import { computed, effectScope, ref } from 'vue'
import { describe, expect, it } from 'vitest'
import { useEditingPin } from './editing_pin'
import type { HistoryRow } from './window'

interface Row extends HistoryRow { revision: number }
const row = (id: string, revision = 1): Row => ({ key: `message:${id}`, messageId: id,
  kind: 'message', estimate: 96, gap: 12, revision })
function fixture() {
  const scope = effectScope(), rows = ref<Row[]>([row('first'), row('last')])
  const pin = scope.run(() => useEditingPin(computed(() => rows.value), ref<HTMLOListElement | null>(null)))!
  return { scope, rows, pin }
}

describe('single history editing pin lifetime', () => {
  it('does not retain a date row when there is no active editor', () => {
    const { scope, rows, pin } = fixture()
    rows.value = [{ key: 'date', kind: 'date', estimate: 24, gap: 16, revision: 0 }, row('first')]
    expect(pin.row.value).toBeUndefined()
    scope.stop()
  })
  it('retains one keyed row outside the data window and updates it on reattachment', () => {
    const { scope, rows, pin } = fixture()
    pin.setEditing('last', true)
    const original = pin.row.value
    rows.value = [row('older')]
    expect(pin.row.value).toBe(original)
    expect(rows.value.map(({ messageId }) => messageId)).toEqual(['older'])
    rows.value = [row('older'), row('last', 2)]
    expect(pin.row.value?.key).toBe('message:last')
    expect(pin.row.value?.revision).toBe(2)
    expect(rows.value).toHaveLength(2)
    scope.stop()
  })

  it('preserves the existing single-pin replacement and matching-close semantics', () => {
    const { scope, pin } = fixture()
    pin.setEditing('first', true); pin.setEditing('last', true)
    pin.setEditing('first', false)
    expect(pin.row.value?.messageId).toBe('last')
    pin.setEditing('last', false)
    expect(pin.row.value).toBeUndefined()
    scope.stop()
  })

  it('clears an evicted row explicitly without adding it to an empty data window', () => {
    const { scope, rows, pin } = fixture()
    pin.setEditing('last', true); rows.value = []
    pin.clear()
    expect(pin.row.value).toBeUndefined()
    expect(rows.value).toEqual([])
    scope.stop()
  })

  it('releases the retained row when its component scope is disposed', () => {
    const { scope, rows, pin } = fixture()
    pin.setEditing('last', true); rows.value = [row('older')]
    scope.stop()
    expect(pin.row.value).toBeUndefined()
  })
})
```

### clients/web/src/conversation/draft_epoch.spec.ts

```ts
import { describe, expect, it } from 'vitest'
import { watch } from 'vue'
import { clearDraftMemory, draftMemoryEpoch } from './draft_memory'

describe('authenticated draft epoch', () => {
  it('publishes a synchronous numeric reset without changing the getter contract', () => {
    const before = draftMemoryEpoch(), observed: number[] = []
    const stop = watch(() => draftMemoryEpoch(), (value) => observed.push(value), { flush: 'sync' })
    clearDraftMemory()
    expect(typeof draftMemoryEpoch()).toBe('number')
    expect(draftMemoryEpoch()).toBe(before + 1)
    expect(observed).toEqual([before + 1])
    stop()
  })
})
```

### clients/web/tests/chat_rhythm/history_edit.html

```html
<!doctype html>
<html lang="ru"><head><meta charset="UTF-8"><title>History edit retention fixture</title></head>
<body><div id="app"></div><script type="module" src="./history_edit.ts"></script></body></html>
```

### clients/web/tests/chat_rhythm/history_edit_data.ts

```ts
export const uid = (n: number) => `10000000-0000-4000-8000-${String(n).padStart(12, '0')}`
export const own = uid(1), peer = uid(2), channelA = uid(3), channelB = uid(4)
export function wire(index: number, channel = channelA, revision = 1) {
  return { id: uid(1000 + index), channel_id: channel, author_id: own,
    client_message_id: uid(3000 + index), body: `History fixture ${index}`,
    revision, deleted: false, attachments: [], mention_user_ids: [peer],
    created_at: new Date(Date.UTC(2026, 9, 31, 0, 0, index)).toISOString() }
}
export function historyPage(before: string | null, after: string | null, count: number, channel = channelA) {
  const index = (id: string) => Number(id.slice(-12)) - 1000
  const high = before ? index(before) - 1 : after ? Math.min(999, index(after) + 20) : 999
  const low = before ? Math.max(0, high - 49) : after ? index(after) + 1 : 1000 - count
  return { messages: Array.from({ length: Math.max(0, high - low + 1) }, (_, i) => wire(high - i, channel)),
    ...(before || !after ? low > 0 ? { next_cursor: uid(1000 + low) } : {} : high < 999 ? { next_cursor: uid(1000 + high) } : {}) }
}
```

### clients/web/tests/chat_rhythm/history_edit.ts

```ts
import { createApp, defineComponent, h, nextTick, ref } from 'vue'
import { createPinia } from 'pinia'
import TextHistoryList from '../../src/conversation/TextHistoryList.vue'
import { useMessageStore } from '../../src/conversation/message_store'
import { useAuthorDirectory } from '../../src/identity/author_directory'
import { clearDraftMemory, draftKey, loadDraft } from '../../src/conversation/draft_memory'
import { clearAuthenticatedState } from '../../src/identity/clear_authenticated_state'
import { useSavedComposer } from '../../src/conversation/use_saved_composer'
import { channelA, channelB, own, peer } from './history_edit_data'
import '../../src/style.css'

const pinia = createPinia(), store = useMessageStore(pinia), authors = useAuthorDirectory(pinia)
for (const [id, name] of [[own, 'Автор'], [peer, 'Участник']])
  authors.acceptOwnProfile({ account_id: id!, login: id!, display_name: name!, role: 'MEMBER' })
const channel = ref(channelA), account = ref(own), composerVisible = ref(true), listVisible = ref(true)
let composer: ReturnType<typeof useSavedComposer<{ id: string }, { id: string }>>
const SavedComposer = defineComponent({ setup() {
  composer = useSavedComposer(own, 'CHANNEL', () => channel.value)
  return () => h('textarea', { 'aria-label': 'Fixture composer', value: composer.draft.value,
    onInput: (event: Event) => { composer.draft.value = (event.target as HTMLTextAreaElement).value } })
} })
await store.open(channelA)
const style = document.createElement('style')
style.textContent = '.history-edit-fixture{height:100vh;padding:12px}.history-edit-fixture nav{display:flex;gap:4px;flex-wrap:wrap}.history-edit-fixture .message-history-wrap{height:650px;position:relative}.history-edit-fixture .messages{height:630px;overflow:auto;position:relative}.history-edit-fixture>textarea{height:50px}'
document.head.append(style)
createApp({ render: () => h('main', { class: 'history-edit-fixture' }, [
  h('nav', [
    h('button', { onClick: async () => { channel.value = channel.value === channelA ? channelB : channelA; await store.open(channel.value) } }, 'Switch channel'),
    h('button', { onClick: () => { account.value = account.value === own ? peer : own } }, 'Switch account'),
    h('button', { onClick: () => { store.channelId = null; store.messages = []; store.historyLoaded = false } }, 'Reset store'),
    h('button', { onClick: () => { store.messages = [] } }, 'Empty store'),
    h('button', { onClick: () => store.channelId === channel.value ? store.refresh() : store.open(channel.value) }, 'Reload history'),
    h('button', { onClick: clearDraftMemory }, 'Clear draft memory'),
    h('button', { onClick: () => clearAuthenticatedState(pinia) }, 'Clear authenticated state'),
    h('button', { onClick: async () => { listVisible.value = false; await nextTick(); listVisible.value = true } }, 'Remount same account'),
    h('button', { onClick: () => { composer.draft.value = 'Late callback'; composerVisible.value = false } }, 'Late composer callback'),
  ]),
  listVisible.value ? h(TextHistoryList, { channelId: channel.value, session: { accountId: account.value, role: 'MEMBER' } }) : null,
  composerVisible.value ? h(SavedComposer) : null,
]) }).use(pinia).mount('#app')
Object.assign(window, { historyEditFixture: {
  cache: () => store.messages.map(({ id }) => id),
  busy: () => store.olderLoading || store.newerLoading,
  remembered: (id = channelA) => loadDraft(draftKey(own, 'CHANNEL', id)),
} })
```

### clients/web/tests/chat_rhythm/history_edit_helpers.ts

```ts
import { expect, type Page } from '@playwright/test'
import { mkdir } from 'node:fs/promises'
import { join } from 'node:path'
import { historyPage, uid, wire } from './history_edit_data'

export async function setup(page: Page, count = 500, width = 1440) {
  await page.setViewportSize({ width, height: 900 })
  const requests: { method: string; body: Record<string, unknown> | null }[] = []
  const state = { conflict: false, deleted: false, revision: 1, pending: null as null | Promise<void> }
  await page.route('**/api/v1/**', async (route) => {
    const request = route.request(), url = new URL(request.url()), match = url.pathname.match(/\/channels\/([^/]+)\/messages(?:\/([^/]+))?$/)
    if (match && request.method() === 'PATCH') {
      const body = request.postDataJSON(); requests.push({ method: 'PATCH', body })
      if (state.pending) await state.pending
      if (state.conflict) { state.conflict = false; return route.fulfill({ status: 409, json: { error: { code: 'CONFLICT' } } }) }
      return route.fulfill({ json: { ...wire(Number(match[2]!.slice(-12)) - 1000, match[1], state.revision + 1), body: body.body } })
    }
    if (match && request.method() === 'GET') {
      const result = historyPage(url.searchParams.get('before'), url.searchParams.get('after'), count, match[1])
      result.messages = result.messages.map((message) => ({ ...message, revision: state.revision,
        ...(state.deleted && message.id === uid(1999) ? { deleted: true, body: '' } : {}) }))
      return route.fulfill({ json: result })
    }
    if (url.pathname.endsWith('/message-reactions')) return route.fulfill({ json: { reactions: [], can_pin: false } })
    if (url.pathname.includes('/members')) return route.fulfill({ json: { members: [] } })
    return route.fulfill({ json: {} })
  })
  await page.goto('/tests/chat_rhythm/history_edit.html')
  await expect.poll(() => cacheSize(page)).toBe(count)
  return { state, requests }
}
export const editor = (page: Page) => page.getByRole('textbox', { name: 'Изменённый текст сообщения', exact: true })
export async function begin(page: Page, index = 999) {
  const row = page.locator(`[data-message-id="${uid(1000 + index)}"]`)
  const list = page.getByRole('log', { name: 'История сообщений' })
  await list.evaluate((element, target) => {
    const ids = (window as any).historyEditFixture.cache().map((id: string) => Number(id.slice(-12)) - 1000)
    const ratio = (target - Math.min(...ids)) / Math.max(1, Math.max(...ids) - Math.min(...ids))
    element.scrollTop = Math.max(0, ratio * element.scrollHeight - element.clientHeight / 2)
    element.dispatchEvent(new Event('scroll'))
  }, index)
  await page.evaluate(() => new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve))))
  await row.hover()
  const menu = row.getByRole('button', { name: 'Действия с сообщением' })
  if (await menu.isVisible()) await menu.click()
  await row.getByRole('button', { name: 'Изменить', exact: true }).click()
  await expect(editor(page)).toBeFocused()
  return editor(page)
}
export async function older(page: Page) {
  const button = page.getByRole('button', { name: 'Показать предыдущие сообщения', exact: true })
  await button.click(); await expect.poll(() => page.evaluate(() => (window as any).historyEditFixture.busy())).toBe(false)
}
export async function newer(page: Page) {
  const button = page.getByRole('button', { name: 'Показать следующие сообщения', exact: true })
  await button.click(); await expect.poll(() => page.evaluate(() => (window as any).historyEditFixture.busy())).toBe(false)
}
export const cacheSize = (page: Page) => page.evaluate(() => (window as any).historyEditFixture.cache().length)
export const cacheHas = (page: Page, index: number) => page.evaluate((id) => (window as any).historyEditFixture.cache().includes(id), uid(1000 + index))
export const geometry = (page: Page) => page.getByRole('log', { name: 'История сообщений' }).evaluate((list) => ({
  rows: list.querySelectorAll('[data-message-id]').length,
  detached: [...list.querySelectorAll('[data-message-id]')].filter((row) => getComputedStyle(row).clipPath === 'inset(50%)').length,
  scrollWidth: list.scrollWidth, clientWidth: list.clientWidth, scrollHeight: list.scrollHeight,
}))
export async function roundtrip(page: Page) { await older(page); for (let i = 0; i < 3; i++) await newer(page) }
export async function capture(page: Page, name: string) {
  const destination = process.env.BOOHTACORD_QA141_CAPTURE_DIR
  if (!destination) return
  await mkdir(destination, { recursive: true })
  await page.evaluate(() => document.fonts.ready)
  await page.evaluate(() => new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve))))
  await page.screenshot({ path: join(destination, `${name}.png`) })
}
```

### clients/web/tests/chat_rhythm/history_edit_eviction.browser.spec.ts

```ts
import { expect, test } from '@playwright/test'
import { begin, cacheHas, cacheSize, capture, geometry, newer, older, roundtrip, setup } from './history_edit_helpers'

for (const repeat of [1, 2, 3]) test(`history edit retains exact active editor through eviction ${repeat}`, async ({ page }) => {
  await setup(page)
  const editor = await begin(page)
  await editor.fill('Uncommitted fixture draft')
  await editor.evaluate((element) => { const input = element as HTMLTextAreaElement
    input.setSelectionRange(4, 12); Object.assign(window, { retainedEditor: input }) })
  await older(page)
  await expect(editor).toHaveCount(1)
  await expect.poll(() => cacheSize(page)).toBe(500)
  await expect.poll(() => cacheHas(page, 999)).toBe(false)
  const bounds = await geometry(page)
  expect(bounds.rows).toBeLessThan(64); expect(bounds.detached).toBe(1)
  expect(bounds.scrollWidth).toBeLessThanOrEqual(bounds.clientWidth + 1)
  await expect(page.getByRole('button', { name: 'Показать предыдущие сообщения', exact: true })).toBeFocused()
  if (repeat === 1) await capture(page, 'detached-reading-1440')
  for (let i = 0; i < 3; i++) await newer(page)
  await expect(editor).toHaveValue('Uncommitted fixture draft')
  expect(await editor.evaluate((element) => element === (window as any).retainedEditor)).toBe(true)
  expect(await editor.evaluate((element) => [(element as HTMLTextAreaElement).selectionStart, (element as HTMLTextAreaElement).selectionEnd])).toEqual([4, 12])
  await expect.poll(() => cacheHas(page, 999)).toBe(true)
  if (repeat === 1) { await editor.scrollIntoViewIfNeeded(); await capture(page, 'restored-editor-1440') }
})

test('history edit mobile roundtrip preserves the same active editor and bounded rows', async ({ page }) => {
  await setup(page, 500, 393); const input = await begin(page)
  await input.fill('Mobile local draft')
  await roundtrip(page)
  await expect(input).toHaveValue('Mobile local draft')
  expect((await geometry(page)).rows).toBeLessThan(64)
  await input.scrollIntoViewIfNeeded(); await capture(page, 'restored-editor-393')
})
for (const [count, index, label] of [[450, 999, 'no eviction'], [500, 700, 'edited row remains cached']] as const)
  test(`history edit positive control ${label}`, async ({ page }) => {
    await setup(page, count); const editor = await begin(page, index)
    await editor.fill('Preserved control'); await older(page)
    await expect(editor).toHaveValue('Preserved control')
    await expect.poll(() => cacheSize(page)).toBe(500)
    await expect.poll(() => cacheHas(page, index)).toBe(true)
  })

test('history edit preserves the oldest row across newer eviction and older return', async ({ page }) => {
  await setup(page)
  for (let i = 0; i < 10; i++) await older(page)
  const list = page.getByRole('log', { name: 'История сообщений' })
  await list.evaluate((element) => { element.scrollTop = 0; element.dispatchEvent(new Event('scroll')) })
  const editor = await begin(page, 0)
  await editor.fill('Oldest local edit'); await newer(page)
  await expect.poll(() => cacheHas(page, 0)).toBe(false)
  await expect(editor).toHaveValue('Oldest local edit')
  await older(page)
  await expect.poll(() => cacheHas(page, 0)).toBe(true)
  await expect(editor).toHaveValue('Oldest local edit')
  await expect.poll(() => cacheSize(page)).toBe(500)
})
```

### clients/web/tests/chat_rhythm/history_edit_privacy.browser.spec.ts

```ts
import { expect, test } from '@playwright/test'
import { begin, editor, newer, older, setup } from './history_edit_helpers'
import { channelA, channelB } from './history_edit_data'

test('history edit detached controls leave Tab order and restore original tabindex on return', async ({ page }) => {
  await setup(page); const input = await begin(page)
  await input.evaluate((element) => Object.assign(window, { originalTabStops:
    [...element.closest('[data-message-id]')!.querySelectorAll<HTMLElement>('button, textarea, [tabindex], summary')]
      .map((target) => [target, target.getAttribute('tabindex')]) }))
  await older(page)
  await expect(input).toHaveCount(1)
  expect(await input.evaluate((element) => [...element.closest('[data-message-id]')!.querySelectorAll<HTMLElement>('button, textarea, [tabindex], summary')]
    .every((target) => target.tabIndex === -1))).toBe(true)
  await input.evaluate((element) => (element as HTMLElement).focus({ preventScroll: true }))
  await expect(input).toBeFocused()
  for (const key of ['Tab', 'Shift+Tab']) {
    await page.keyboard.press(key)
    expect(await page.evaluate(() => getComputedStyle(document.activeElement!.closest('[data-message-id]') ?? document.body).clipPath)).not.toBe('inset(50%)')
  }
  for (let i = 0; i < 3; i++) await newer(page)
  expect(await page.evaluate(() => (window as any).originalTabStops.every(([element, value]: [HTMLElement, string | null]) => element.getAttribute('tabindex') === value))).toBe(true)
})

for (const detached of [false, true]) for (const trigger of [
  'Switch account', 'Switch channel', 'Reset store', 'Empty store', 'Clear draft memory', 'Clear authenticated state',
]) test(`history edit privacy ${trigger} clears ${detached ? 'detached' : 'visible'} editor`, async ({ page }) => {
  await setup(page); const input = await begin(page)
  await input.fill('Private unsaved fixture')
  if (detached) { await older(page); await expect(input).toHaveCount(1) }
  await page.getByRole('button', { name: trigger, exact: true }).click()
  await expect(editor(page)).toHaveCount(0)
  if (trigger.startsWith('Switch')) await page.getByRole('button', { name: trigger, exact: true }).click()
  else if (trigger.includes('store')) await page.getByRole('button', { name: 'Reload history', exact: true }).click()
  else await page.getByRole('button', { name: 'Remount same account', exact: true }).click()
  await expect(editor(page)).toHaveCount(0)
  expect(await page.locator('textarea').evaluateAll((elements) => elements.some((element) => element.value === 'Private unsaved fixture'))).toBe(false)
})

test('history edit auth clear cannot resurrect composer drafts from old callbacks or unmount', async ({ page }) => {
  await setup(page)
  const composer = page.getByRole('textbox', { name: 'Fixture composer', exact: true })
  await composer.fill('Channel A draft')
  await page.getByRole('button', { name: 'Switch channel', exact: true }).click()
  await expect(composer).toHaveValue('')
  await composer.fill('Channel B draft')
  await page.getByRole('button', { name: 'Switch channel', exact: true }).click()
  await expect(composer).toHaveValue('Channel A draft')
  expect(await page.evaluate((id) => (window as any).historyEditFixture.remembered(id)?.body, channelB)).toBe('Channel B draft')
  await page.getByRole('button', { name: 'Clear draft memory', exact: true }).click()
  await page.getByRole('button', { name: 'Late composer callback', exact: true }).click()
  await expect(composer).toHaveCount(0)
  for (const id of [channelA, channelB])
    expect(await page.evaluate((key) => (window as any).historyEditFixture.remembered(key), id)).toBeNull()
})
```

### clients/web/tests/chat_rhythm/history_edit_state.browser.spec.ts

```ts
import { expect, test } from '@playwright/test'
import { begin, editor, older, roundtrip, setup } from './history_edit_helpers'
import { peer } from './history_edit_data'

test('history edit conflict preserves text mentions and revision through eviction', async ({ page }) => {
  const { state, requests } = await setup(page); state.conflict = true
  const input = await begin(page); await input.fill('Conflict fixture draft')
  await page.getByRole('button', { name: 'Сохранить', exact: true }).click()
  await expect(page.getByRole('alert')).toContainText('Обновите версию')
  await roundtrip(page)
  await expect(input).toHaveValue('Conflict fixture draft')
  await expect(page.getByRole('button', { name: 'Сохранить', exact: true })).toBeDisabled()
  await expect(page.getByRole('button', { name: /^Убрать упоминание / })).toHaveCount(1)
  state.revision = 2
  await page.getByRole('button', { name: 'Обновить версию', exact: true }).click()
  await expect(page.getByRole('status').filter({ hasText: 'Версия обновлена' })).toHaveCount(1)
  await expect(input).toHaveValue('Conflict fixture draft')
  await page.getByRole('button', { name: 'Сохранить', exact: true }).click()
  await expect(input).toHaveCount(0)
  expect(requests.map(({ body }) => body)).toEqual([
    { body: 'Conflict fixture draft', expected_revision: 1, mention_user_ids: [peer] },
    { body: 'Conflict fixture draft', expected_revision: 2, mention_user_ids: [peer] },
  ])
})

test('history edit deleted refresh keeps the existing draft-for-copy notice', async ({ page }) => {
  const { state } = await setup(page); state.conflict = true
  const input = await begin(page); await input.fill('Draft for copying')
  await page.getByRole('button', { name: 'Сохранить', exact: true }).click()
  await expect(page.getByRole('button', { name: 'Обновить версию', exact: true })).toHaveCount(1)
  await roundtrip(page); state.deleted = true; state.revision = 2
  await page.getByRole('button', { name: 'Обновить версию', exact: true }).click()
  await expect(page.getByRole('alert')).toContainText('черновик сохранён для копирования')
  await expect(input).toHaveValue('Draft for copying')
  await expect(page.getByRole('button', { name: 'Сохранить', exact: true })).toBeDisabled()
})

test('history edit pending request remains duplicate guarded through eviction and return', async ({ page }) => {
  const { state, requests } = await setup(page)
  let release!: () => void; state.pending = new Promise<void>((resolve) => { release = resolve })
  const input = await begin(page); await input.fill('Pending draft')
  await page.getByRole('button', { name: 'Сохранить', exact: true }).click()
  await expect(input).toBeDisabled()
  await roundtrip(page)
  await expect(input).toBeDisabled()
  await expect(page.getByRole('button', { name: 'Обрабатываем…', exact: true })).toBeDisabled()
  expect(requests).toHaveLength(1); release()
  await expect(input).toHaveCount(0); expect(requests).toHaveLength(1)
  await expect(page.getByRole('button', { name: 'Показать следующие сообщения', exact: true })).toBeFocused()
})

for (const key of ['Escape', 'Control+Enter']) test(`history edit detached ${key} closes only its editor and restores history focus`, async ({ page }) => {
  const { requests } = await setup(page)
  const input = await begin(page); await input.fill('Detached command draft'); await older(page)
  await expect(input).toHaveCount(1)
  await input.evaluate((element) => (element as HTMLElement).focus({ preventScroll: true }))
  await page.keyboard.press(key)
  await expect(editor(page)).toHaveCount(0)
  expect(await page.getByRole('log', { name: 'История сообщений' }).evaluate((element) => element.contains(document.activeElement))).toBe(true)
  expect(requests).toHaveLength(key === 'Escape' ? 0 : 1)
  if (key !== 'Escape') expect(requests[0]?.body).toEqual({ body: 'Detached command draft', expected_revision: 1, mention_user_ids: [peer] })
})
```


## Multi-editor preservation finding — supersedes single-controller assumption

Fresh current component control proved two simultaneous visible editors are allowed. Ordinary virtual scroll removes the first editor while both messages remain in cache500; only the latest pin survives. The result/log are retained in .out/issue141/multiple-edit-diagnostic*. This is a real same-invariant gap, not accepted preservation, and single-pin-only implementation cannot close141.

Root directed preservation of multiple editors, with no user question or silent UI-cardinality reduction. Proposed revised design pending internal review: a TEXT-only typed optional provider owns at most500 active controller leases; it never silently evicts unsaved state. Normal MessageItem users outside this provider keep their default local controller. Retain only one focused/active keyed DOM pin; other active controllers/selection survive remount without extra hidden rows. Release entries on successful save/cancel; cap blocks only a new begin and explains save/cancel action. Scope/generation clear wipes data synchronously and fences stale async completions. MessageItem/controller callback semantics remain unchanged.

Production remains HOLD until the fresh independent built-AppShell/API baseline and revised design review. The earlier exact single-pin helper plan remains useful but is insufficient alone; do not execute it as a complete141 fix. Add the multiple-editor failing test to the retained profile and extend it through eviction/reattachment in the revised test plan. No old tests are deleted or skipped.

## Task 2R — approved multi-controller retention (supersedes single-pin-only implementation)

Root approved preservation of MULTI editing with up to500 ACTIVE states; no unsaved state is evicted. Keep one focused/active DOM pin only. Other editors preserve their controller references and numeric selection through unmount/rebind. The registry must never retain an HTMLElement or unmounted Vue instance; component ports are unbound with an identity token on unmount, and late async completions are generation/entry fenced. Base message_edit_controller.ts remains byte-identical.

Additional production files: history_window/editing_state/{registry,entry,context}.ts and history_window/editing_tabstops.ts; MessageItem optional binding. Total planned changed production files11, hard16. Direct test files: pin, registry, async, epoch plus four browser files =8; fixture/support files separate. MessageItem currently118 lines; replace the controller import/call, move the existing editInput ref before binding, add one blocked-feedback line outside the editing branch, keep final<=120.

The following code is authoritative for new controller modules. Original typed controller and current save/refresh ports remain the behavior authority.

### history_window/editing_state/registry.ts

```ts
import { ref } from 'vue'
import { EditorEntry, type EditPorts, type EntryOwner } from './entry'
export const MAX_ACTIVE_HISTORY_EDITS = 500
export function createHistoryEditorRegistry() {
  const entries = new Map<string, EditorEntry>(), changed = ref(0)
  let generation = 0, disposed = false
  const owner: EntryOwner = {
    valid: (entry) => !disposed && entry.generation === generation,
    reserve: (entry) => {
      if (!owner.valid(entry)) return false
      const current = entries.get(entry.id)
      if (current) return current === entry
      if (entries.size >= MAX_ACTIVE_HISTORY_EDITS) return false
      entries.set(entry.id, entry); changed.value++; return true
    },
    release: (entry) => { if (entries.get(entry.id) === entry) { entries.delete(entry.id); changed.value++ } },
  }
  function clear(): void {
    generation++
    const previous = [...entries.values()]; entries.clear(); changed.value++
    for (const entry of previous) entry.wipe()
  }
  return {
    get size() { return entries.size },
    has: (id: string) => { changed.value; return entries.has(id) },
    bind: (id: string, ports: EditPorts) => (entries.get(id) ?? new EditorEntry(id, generation, owner)).bind(ports),
    clear,
    dispose: () => { disposed = true; clear() },
  }
}
export type HistoryEditorRegistry = ReturnType<typeof createHistoryEditorRegistry>
```

### history_window/editing_state/entry.ts

```ts
import { ref } from 'vue'
import { useMessageEditController, type EditResult } from '../../message_edit_controller'
export type EditPorts = Parameters<typeof useMessageEditController>[0]
export interface EntryOwner { valid(entry: EditorEntry): boolean; reserve(entry: EditorEntry): boolean; release(entry: EditorEntry): void }
type Selection = { start: number; end: number; direction: 'forward' | 'backward' | 'none' }
type SelectionInput = Pick<HTMLTextAreaElement, 'selectionStart' | 'selectionEnd' | 'selectionDirection'>
type SelectionOutput = Pick<HTMLTextAreaElement, 'setSelectionRange'>
const unavailable: EditResult = { kind: 'stale', message: 'Сообщение недоступно.' }

export class EditorEntry {
  private ports: EditPorts | null = null
  private token: symbol | null = null
  private selection: Selection | null = null
  readonly state
  readonly editor
  constructor(readonly id: string, readonly generation: number, private readonly owner: EntryOwner) {
    this.state = useMessageEditController({
      save: (...args) => owner.valid(this) && this.ports ? this.ports.save(...args) : Promise.resolve(unavailable),
      refresh: () => owner.valid(this) && this.ports ? this.ports.refresh() : Promise.resolve(null),
    })
    const state = this.state, blockedReason = ref<string | null>(null)
    const run = async (action: () => Promise<void>): Promise<void> => {
      if (!owner.valid(this)) { this.wipe(); return }
      await action()
      if (!owner.valid(this)) this.wipe()
      else if (!state.editing.value) owner.release(this)
    }
    this.editor = { ...state, blockedReason,
      begin: (message: Parameters<typeof state.begin>[0]) => {
        if (!owner.valid(this)) { this.wipe(); return }
        if (!owner.reserve(this)) { blockedReason.value = 'Сначала сохраните или отмените одно из открытых редактирований.'; return }
        blockedReason.value = null; state.begin(message)
      },
      cancel: () => {
        if (!owner.valid(this)) { this.wipe(); return }
        state.cancel(); if (!state.editing.value) owner.release(this)
      },
      submit: () => run(state.submit), refreshVersion: () => run(state.refreshVersion),
    }
  }
  wipe(): void {
    const state = this.state
    this.ports = null; this.token = null; this.selection = null
    state.editing.value = false; state.body.value = ''; state.mentionUserIds.value = []
    state.baseRevision.value = 0; state.pending.value = false; state.needsRefresh.value = false
    state.error.value = null; state.notice.value = null; this.editor.blockedReason.value = null
  }
  bind(ports: EditPorts) {
    const token = Symbol('mounted-editor'); this.ports = ports; this.token = token
    const current = () => this.owner.valid(this) && this.token === token
    return { editor: this.editor,
      unbind: () => { if (this.token === token) { this.ports = null; this.token = null } },
      rememberSelection: (input: SelectionInput | null) => {
        if (current() && this.state.editing.value && input) this.selection = {
          start: input.selectionStart, end: input.selectionEnd, direction: input.selectionDirection }
      },
      restoreSelection: (input: SelectionOutput | null) => {
        if (current() && this.state.editing.value && input && this.selection)
          input.setSelectionRange(this.selection.start, this.selection.end, this.selection.direction)
      },
    }
  }
}
```

### history_window/editing_state/context.ts

```ts
import { inject, onBeforeUnmount, provide, ref, watch, type InjectionKey, type Ref } from 'vue'
import { useMessageEditController } from '../../message_edit_controller'
import { createHistoryEditorRegistry, type HistoryEditorRegistry } from './registry'
import type { EditPorts } from './entry'
export type { EditResult } from '../../message_edit_controller'
const key: InjectionKey<HistoryEditorRegistry> = Symbol('text-history-editors')
export function provideHistoryEditors() {
  const registry = createHistoryEditorRegistry(); provide(key, registry); return registry
}
export function useHistoryMessageEditor(id: string, ports: EditPorts, input: Ref<HTMLTextAreaElement | null>) {
  const registry = inject(key, null)
  if (!registry) return { ...useMessageEditController(ports), blockedReason: ref<string | null>(null) }
  const binding = registry.bind(id, ports)
  watch(input, (element, _previous, cleanup) => {
    if (!element) return
    binding.restoreSelection(element)
    const remember = () => binding.rememberSelection(element)
    element.addEventListener('select', remember); element.addEventListener('blur', remember)
    cleanup(() => { remember(); element.removeEventListener('select', remember); element.removeEventListener('blur', remember) })
  }, { flush: 'post' })
  onBeforeUnmount(() => { binding.rememberSelection(input.value); binding.unbind() })
  return binding.editor
}
```

- Bind provider in use_text_history_list before children setup. Synchronous scope reset must call historyWindow.clearPins() BEFORE registry.clear(), so privacy clearing does not schedule closing-editor focus restoration. onBeforeUnmount calls clearPins then registry.dispose().
- Prefer the actual focused message for the one DOM pin. If focus enters an already-open editor, make that editor the retained row; provider.has(id) supplies this knowledge without retaining component/DOM objects in the registry. When no focused row exists, retain the existing active editing fallback. All other editor controllers survive virtual unmount through registry, without500 DOM nodes.
- MessageItem's existing editInput ref moves above controller construction. Replace its import with useHistoryMessageEditor/type EditResult from the optional context module, call useHistoryMessageEditor(props.message.id, currentPorts, editInput), keep original beginEdit/shortcuts/roles/actions and mentions unchanged. Add `<p v-if="editor.blockedReason.value" class="message-send-status" role="status">{{ editor.blockedReason.value }}</p>` outside the editing template (or destructure its ref before template use, matching Vue setup unwrapping).
- Preserve old MessageItem default controller behavior for DM/context callers without a TEXT provider. There is no global registry or persistence.
- Do not store an HTML element, input ref or Vue instance in registry/entry; only live mounted ports, refs/controller state, numeric selection and symbol/generation tokens. Unbind clears mounted ports/token, even while a pending promise completes.
- Retain new registry.spec.ts and async.spec.ts in the plan appendix before production edits. They cover exact500 cap/no silent draft eviction, slot release, selection/rebind, unbound ports, pending success after unmount, conflict/duplicate guards, synchronous wipe, same-ID replacement ownership and late completion.
- Extend the two-editor browser counterexample through ordinary virtual scroll, cache eviction and return, both draft/controller/caret states and bounded DOM/cache; no test deletion or skip. Root will add its actual built-AppShell/network multi-editor witness.

### Pin/registry bridge precision

The registry.has accessor reads a tiny reactive revision, changed only on active reserve/release/clear. useHistoryWindow accepts an optional isEditing callback (TEXT passes registry.has; generic callers retain their existing default). For TEXT, a synchronous watch clears the retained editing row once its controller is no longer active. This prevents a successful save while unmounted from later remounting a phantom closed pin. Focus-in on an active registered editor selects that row as the single retained DOM pin; a genuinely focused normal row still uses the existing focus pin. No iteration over registry entries participates in rendering.

Selection hooks watch only the component-local textarea ref. The registry stores a copied numeric start/end/direction, never the input or ref. The typed entry binding token ensures an old unmount cannot clear newly rebound ports or overwrite newer selection. Pending promises may finish after unmount; the entry wrapper releases success even without a mounted component, and generation/identity checks protect a new same-ID lease after clear.

The multiple-editor retained regression now explicitly scrolls back before asserting draft preservation. Offviewport nonactive editor unmount itself is allowed; the failure is loss of its unsaved state after the same cached message returns. It then extends through actual fixture older/newer eviction and checks both texts/caret states while DOM stays bounded.

### clients/web/src/conversation/history_window/editing_state/registry.spec.ts

```ts
import { describe, expect, it, vi } from 'vitest'
import { createHistoryEditorRegistry, MAX_ACTIVE_HISTORY_EDITS } from './registry'
const message = { body: 'Original', mentionUserIds: ['peer'], revision: 1 }
const ports = () => ({ save: vi.fn().mockResolvedValue({ kind: 'saved' }), refresh: vi.fn().mockResolvedValue({ revision: 2, deleted: false }) })

describe('bounded history editor controller registry', () => {
  it('retains independent controllers across unmount and rebind without retaining old ports', async () => {
    const registry = createHistoryEditorRegistry(), firstPorts = ports(), secondPorts = ports()
    const first = registry.bind('first', firstPorts), second = registry.bind('second', secondPorts)
    first.editor.begin(message); second.editor.begin(message)
    first.editor.body.value = 'First unsaved'; second.editor.body.value = 'Second unsaved'
    first.rememberSelection({ selectionStart: 3, selectionEnd: 8, selectionDirection: 'backward' })
    first.unbind(); second.unbind()
    expect(registry.size).toBe(2)
    const reboundPorts = ports(), rebound = registry.bind('first', reboundPorts)
    expect(rebound.editor).toBe(first.editor)
    expect(rebound.editor.body.value).toBe('First unsaved')
    expect(rebound.editor.mentionUserIds.value).toEqual(['peer'])
    const selection = vi.fn(); rebound.restoreSelection({ setSelectionRange: selection })
    expect(selection).toHaveBeenCalledWith(3, 8, 'backward')
    await rebound.editor.submit()
    expect(firstPorts.save).not.toHaveBeenCalled()
    expect(reboundPorts.save).toHaveBeenCalledWith('First unsaved', ['peer'], 1)
    expect(registry.size).toBe(1)
    const other = registry.bind('second', ports())
    expect(other.editor.body.value).toBe('Second unsaved')
    other.editor.cancel(); expect(registry.size).toBe(0)
  })

  it('caps exactly500 active states without silently evicting any draft and releases a cancelled slot', () => {
    const registry = createHistoryEditorRegistry(), heapBefore = process.memoryUsage().heapUsed
    const bindings = Array.from({ length: MAX_ACTIVE_HISTORY_EDITS }, (_, index) => {
      const binding = registry.bind(String(index), ports())
      binding.editor.begin({ ...message, body: `Draft ${index}` }); return binding
    })
    expect(MAX_ACTIVE_HISTORY_EDITS).toBe(500); expect(registry.size).toBe(500)
    const extra = registry.bind('extra', ports()); extra.editor.begin(message)
    expect(extra.editor.editing.value).toBe(false)
    expect(extra.editor.blockedReason.value).toContain('сохраните или отмените')
    expect(bindings[0]!.editor.body.value).toBe('Draft 0')
    expect(bindings[499]!.editor.body.value).toBe('Draft 499')
    bindings[0]!.editor.cancel(); extra.editor.begin(message)
    expect(extra.editor.editing.value).toBe(true); expect(registry.size).toBe(500)
    console.info(JSON.stringify({ scope: 'native500-active-state observation; noGC or SLO claim', heapBefore,
      heapAfter500: process.memoryUsage().heapUsed, activeStates: registry.size }))
    registry.clear(); expect(registry.size).toBe(0)
    expect(bindings[499]!.editor.body.value).toBe('')
    expect(extra.editor.mentionUserIds.value).toEqual([])
  })

  it('cannot call an unmounted component port and removes all data on disposal', async () => {
    const registry = createHistoryEditorRegistry(), original = ports()
    const binding = registry.bind('first', original); binding.editor.begin(message); binding.unbind()
    await binding.editor.submit(); expect(original.save).not.toHaveBeenCalled()
    expect(binding.editor.body.value).toBe('Original')
    registry.dispose(); binding.editor.begin(message)
    expect(binding.editor.editing.value).toBe(false)
    expect(binding.editor.body.value).toBe(''); expect(registry.size).toBe(0)
  })
})
```

### clients/web/src/conversation/history_window/editing_state/async.spec.ts

```ts
import { describe, expect, it, vi } from 'vitest'
import { createHistoryEditorRegistry } from './registry'
import type { EditResult } from '../../message_edit_controller'
const message = { body: 'Original', mentionUserIds: ['peer'], revision: 1 }
function pendingPorts() {
  let finish!: (result: EditResult) => void
  return { finish: (result: EditResult) => finish(result),
    ports: { save: vi.fn(() => new Promise<EditResult>((resolve) => { finish = resolve })),
      refresh: vi.fn().mockResolvedValue({ revision: 2, deleted: false }) } }
}

describe('history editor asynchronous ownership fences', () => {
  it('releases successful pending saves after their MessageItem has unmounted', async () => {
    const registry = createHistoryEditorRegistry(), pending = pendingPorts()
    const binding = registry.bind('first', pending.ports); binding.editor.begin(message)
    binding.editor.body.value = 'Pending draft'; const saving = binding.editor.submit()
    binding.editor.cancel(); expect(registry.size).toBe(1)
    binding.unbind(); pending.finish({ kind: 'saved' }); await saving
    expect(registry.size).toBe(0); expect(binding.editor.editing.value).toBe(false)
  })

  it('preserves pending and conflict state through rebind without duplicate save', async () => {
    const registry = createHistoryEditorRegistry(), pending = pendingPorts()
    const first = registry.bind('first', pending.ports); first.editor.begin(message)
    first.editor.body.value = 'Conflict draft'; const saving = first.editor.submit(); first.unbind()
    const nextPorts = { save: vi.fn().mockResolvedValue({ kind: 'saved' }), refresh: vi.fn().mockResolvedValue({ revision: 2, deleted: false }) }
    const rebound = registry.bind('first', nextPorts)
    expect(rebound.editor.pending.value).toBe(true); await rebound.editor.submit()
    expect(nextPorts.save).not.toHaveBeenCalled()
    pending.finish({ kind: 'conflict', message: 'Conflict fixture' }); await saving
    expect(rebound.editor.body.value).toBe('Conflict draft')
    expect(rebound.editor.needsRefresh.value).toBe(true)
    expect(rebound.editor.error.value).toBe('Conflict fixture')
    await rebound.editor.refreshVersion(); expect(rebound.editor.baseRevision.value).toBe(2)
    await rebound.editor.submit(); expect(nextPorts.save).toHaveBeenCalledWith('Conflict draft', ['peer'], 2)
    expect(registry.size).toBe(0)
  })

  it('clears data synchronously and an old completion cannot delete or repopulate a newer same-ID lease', async () => {
    const registry = createHistoryEditorRegistry(), pending = pendingPorts()
    const old = registry.bind('same', pending.ports); old.editor.begin(message)
    old.editor.body.value = 'Private old draft'; const saving = old.editor.submit()
    registry.clear()
    expect(old.editor.body.value).toBe(''); expect(old.editor.editing.value).toBe(false)
    expect(old.editor.mentionUserIds.value).toEqual([])
    const replacement = registry.bind('same', { save: vi.fn(), refresh: vi.fn() })
    replacement.editor.begin({ ...message, body: 'New account draft' })
    old.unbind(); pending.finish({ kind: 'conflict', message: 'Old result' }); await saving
    expect(registry.size).toBe(1)
    expect(registry.bind('same', { save: vi.fn(), refresh: vi.fn() }).editor).toBe(replacement.editor)
    expect(replacement.editor.body.value).toBe('New account draft')
    expect(old.editor.body.value).toBe(''); expect(old.editor.error.value).toBeNull()
  })
})
```

### clients/web/tests/chat_rhythm/history_edit_multiple.browser.spec.ts

```ts
import { expect, test } from '@playwright/test'
import { writeFile } from 'node:fs/promises'
import { begin, cacheHas, cacheSize, newer, older, scrollToRow, setup } from './history_edit_helpers'
import { uid } from './history_edit_data'

test('history edit diagnostic two simultaneous editors preserve both unsaved values on ordinary scroll', async ({ page }) => {
  await setup(page)
  await (await begin(page)).fill('First unsaved fixture')
  await page.locator(`[data-message-id="${uid(1999)}"] textarea`).evaluate((element) => {
    const input = element as HTMLTextAreaElement; input.setSelectionRange(2, 7)
  })
  const second = page.locator(`[data-message-id="${uid(1998)}"]`)
  await second.hover(); await second.getByRole('button', { name: 'Изменить', exact: true }).click()
  const firstInput = page.locator(`[data-message-id="${uid(1999)}"] textarea`)
  const secondInput = second.locator('textarea')
  await secondInput.fill('Second unsaved fixture')
  await secondInput.evaluate((element) => { const input = element as HTMLTextAreaElement
    input.setSelectionRange(1, 5); Object.assign(window, { originalSecondEditor: input }) })
  await expect(firstInput).toHaveValue('First unsaved fixture')
  await expect(secondInput).toHaveValue('Second unsaved fixture')
  const before = { first: await firstInput.inputValue(), second: await secondInput.inputValue() }
  await page.getByRole('log', { name: 'История сообщений' }).evaluate((element) => {
    element.scrollTop = 0; element.dispatchEvent(new Event('scroll'))
  })
  await page.evaluate(() => new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve))))
  const result = { scope: 'production component fixture only; no actual AppShell/API claim', before,
    after: { firstEditorCount: await firstInput.count(), secondEditorCount: await secondInput.count(),
      cacheSize: await cacheSize(page), firstMessageStillCached: await cacheHas(page, 999),
      secondMessageStillCached: await cacheHas(page, 998) }, afterReturn: { firstEditorCount: -1, secondEditorCount: -1 } }
  await scrollToRow(page, 999)
  result.afterReturn = { firstEditorCount: await firstInput.count(), secondEditorCount: await secondInput.count() }
  await writeFile(test.info().outputPath('diagnostic.json'), JSON.stringify(result, null, 2))
  await expect(firstInput).toHaveValue('First unsaved fixture')
  await expect(secondInput).toHaveValue('Second unsaved fixture')
  expect(await firstInput.evaluate((element) => [(element as HTMLTextAreaElement).selectionStart, (element as HTMLTextAreaElement).selectionEnd])).toEqual([2, 7])
  await older(page); for (let i = 0; i < 3; i++) await newer(page)
  await expect(firstInput).toHaveValue('First unsaved fixture')
  await expect(secondInput).toHaveValue('Second unsaved fixture')
  expect(await secondInput.evaluate((element) => element === (window as any).originalSecondEditor)).toBe(true)
  expect(await secondInput.evaluate((element) => [(element as HTMLTextAreaElement).selectionStart, (element as HTMLTextAreaElement).selectionEnd])).toEqual([1, 5])
  await expect.poll(() => cacheSize(page)).toBe(500)
})
```

### Reset notification ordering

Because epoch becomes reactive, clearDraftMemory must empty its memory map BEFORE publishing the new epoch (`memory.clear(); epoch.value++`). This preserves the numeric API while ensuring synchronous reset observers cannot read the old saved draft. The epoch unit test now checks that loadDraft is already null inside its synchronous callback, as well as numeric increment. Existing composer delayed-callback/onUnmount guards remain unchanged.

### Pending-source state

All test/plan changes above are pre-implementation. No production file has been edited. The independent root actual baseline and revised design GO remain required before executing the source patch. Component REDs and unit expectation are scoped explicitly; no production/media acceptance is inferred.

### Focus ownership edge cases before implementation

- Focusing the retained detached editor must not clear its row merely because rows.find cannot find the evicted ID. setEditing(true) replaces the retained row only when the current rows contain that message; otherwise the matching snapshot is kept. The unit fixture explicitly checks this refocus case.
- Save can disable the textarea before completion and thereby leave activeElement at body. Track only the last focused message ID inside the pin helper, reset by real list focus-in (including paging controls). At close, restore a stable history control only if current focus is still within that row, or is body with the matching previous owner. A focus on a load button/outside interactive element prevents restoration. Do not store DOM elements in the registry.
- A pin-local reset version invalidates scheduled nextTick focus work on scope clear/unmount, so a pending old close cannot focus a new account/channel. Clear pins before registry wipe.
- These are scoped pin lifecycle fixes, not a rewrite of ResizeObserver geometry or a change to editor shortcuts. Retained browser detached Escape/Save, pager no-steal and scope-reset tests are the executable acceptance.

## Execution checkpoint — source implementation authorized and complete

Root qualified actual built-AppShell baseline on source46e for1440x1000 and393x844: each has3semantic eviction failures and2positive controls, normalTLS+realAPI, cache<=500, unchanged1000rows/hash/revision1,0message mutations and normalUIlogout/browsercleanup. Root wide verdict SHA65a0b128a41ed72ddf783071da519f38c03eff6e654c73c155313dc877764ba2; root actual multi-scroll return verdict SHA2b9701209937612f25cc5451ea6988c83e5fe859320b954c1e3ace2be9b3082d. This opened the production gate; earlier HOLD paragraphs remain historical prerequisites, not current blockers.

Implemented11 production files, max119lines. Base message_edit_controller.ts, history cache/merge/paging/index, API contracts and context/read implementations stay byte-identical. Additional integration detail: detached rows use data-retained-message-id only; normal data-message-id is absent so unchanged context/anchor/read selectors ignore their clipped1px box. Pin focus/close selectors understand both markers. Native browser explicitly checks this and counts normal+retained DOM together.

Current local results: nearest34PASS, fullWeb1731PASS, productionTS/VitebuildPASS, newcomponent27PASS before final capacity UI addition, parity verifierPASS, contract verificationPASS (129public/4private), pinnedLinuxPython3.12.15 policy22PASS. Isolated retention-disabled mutation3semanticFAIL after eviction AND after return, both controlsPASS; original checkout never mutated. Registry500 observation includes test/mock allocations and noGC, not a memory/SLO guarantee.

Retained diagnostics: initial fixture desktop-menu/style setup failure, initial fixed run23PASS/4focusFAIL, second26PASS/1wrongremoved-pager-testexpectationFAIL, then27PASS. FullWindowsprofile80PASS/5FAIL:4unchanged200percent native-window geometry assertions observed379/709 vs390/720, plus one fixture-assignment readiness race now fixed with attached wait. No skip/assertion weakened. Windowsgeometry remains a declared runner limitation; pinnedLinux canonical/fullhosted profile must still pass. WindowsPOSIXprocess policy test2setupERROR unsupportedkillpg/SIGKILL retained; exact owned30s helpers laterCIMabsent0; Linux3.14.4 supplemental22PASS is separate from actual pinned3.12.15 final22PASS.

Remaining before merge/closure: final28component check, final reviewed capture hashes, exact source freeze, canonical5featuresWeb real-stack with source-resolution review, full exact-head hostedCI and root actual fixed/Tier2/Tier3+cleanup verdict. Root requested suspension of localheavychecks during its announced baseline/fixed performance windows; canonical has not started and must be sequenced explicitly. No production operations or physical/native/media gate claimed.

## Final local source-freeze checkpoint

All28dedicated component browser regressionsPASS, finalTS/VitebuildPASS and samefinal-fixture retention-disabled mutation3semanticFAIL/2controlsPASS (aftereviction andafterreturn), no skips. Four component PNGs reviewed ORIGINAL; three prior PNGs byte-identical, capacityfeedback visible andDOM1with500activecontrollerstates. Productinputs11/max119 and all preserved controller/cache/paging/index/context/read/API files were byte-compared to base. Initial source evidence is evidence/qa/issue141-history-edit-retention-2026-10-31.json. Future canonical/hosted/root/runtime publication updates belong to additive evidence, not diagnostic-only changes to this frozen product head. Canonical remains pending root measurement windows; merge/closure HOLD persists.
