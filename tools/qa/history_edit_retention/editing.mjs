import assert from 'node:assert/strict'
import { api, channel, expect, status } from '../client_lifecycle/request.mjs'
import { beginLatest, editor, historyState, pageNewer, pageOlder, settle } from './dom.mjs'

export async function editingAcceptance(a, b, channelId, directory, report) {
  await channel(a, 'HistoryLab', channelId)
  await expect.poll(async () => (await historyState(a)).channel).toBe(channelId)
  await expect.poll(async () => (await historyState(a)).loaded).toBe(true)
  console.log('stage=actual-history-initial-cache-'+(await historyState(a)).count)
  for (let n = 0; n < 9; n++) {
    await pageOlder(a)
    console.log(`stage=actual-history-old-page-${n+1}-cache-${(await historyState(a)).count}`)
  }
  assert.equal((await historyState(a)).count, 500)
  const id = (await historyState(a)).last
  await beginLatest(a)
  const input = editor(a), draft = 'Synthetic unsaved history edit'
  await input.fill(draft)
  await input.evaluate(element => { element.setSelectionRange(4, 15); window.retainedHistoryEditor = element })
  await pageOlder(a)
  assert.equal((await historyState(a)).count, 500)
  assert.equal((await historyState(a)).detached, 1)
  await expect(a.locator('[data-message-id="'+id+'"]')).toHaveCount(0)
  await expect(input).toHaveValue(draft)
  for (let n = 0; n < 3; n++) await pageNewer(a)
  await expect(input).toHaveValue(draft)
  assert.equal(await input.evaluate(element => element === window.retainedHistoryEditor), true)
  assert.deepEqual(await input.evaluate(element => [element.selectionStart, element.selectionEnd]), [4, 15])
  await input.focus()
  const viewport = a.viewportSize()
  await a.setViewportSize({ ...viewport, width: viewport.width+1 }); await settle(a)
  await expect(input).toBeFocused()
  await a.setViewportSize(viewport); await settle(a)
  await expect(input).toBeFocused()
  await input.scrollIntoViewIfNeeded(); await settle(a)
  await a.screenshot({ path: directory+'/retained-editor.png' })
  const current = (await api(b, `/channels/${channelId}/messages?at=${id}&limit=20`)).body.messages.find(row => row.id === id)
  status(await api(b, `/channels/${channelId}/messages/${id}`, 'PATCH', {
    body: 'Synthetic concurrent server edit', expected_revision: current.revision,
  }), 200)
  await input.locator('..').getByRole('button', { name: 'Сохранить', exact: true }).click()
  await expect(input).toHaveValue(draft)
  await a.getByRole('button', { name: 'Обновить версию', exact: true }).click()
  await expect(input).toHaveValue(draft)
  await input.locator('..').getByRole('button', { name: 'Сохранить', exact: true }).click()
  await expect(editor(a)).toHaveCount(0)
  const saved = (await api(b, `/channels/${channelId}/messages?at=${id}&limit=20`)).body.messages.find(row => row.id === id)
  assert.equal(saved.body, draft); assert.equal(saved.revision, current.revision+2)
  await a.evaluate(() => { delete window.retainedHistoryEditor })
  report.editing = { actual_api: true, exact_draft_and_selection: true, same_dom_editor: true,
    detached_rows: 1, cache_limit: 500, resize_preserves_focus: true,
    conflict_preserves_draft: true, saved_revision_increment: 2 }
  console.log('stage=actual-history-edit-retention-accepted')
}
