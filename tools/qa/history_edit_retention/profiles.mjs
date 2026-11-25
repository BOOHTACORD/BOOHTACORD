import assert from 'node:assert/strict'
import { performance } from 'node:perf_hooks'
import { api, channel, expect, status } from '../client_lifecycle/request.mjs'
import { historyState, pageOlder, settle } from './dom.mjs'
import { seedHistory, validateMessageIdentifiers } from './seed.mjs'

export async function historyProfiles(page, category, foreign, owner) {
  const results = [], cdp = await page.context().newCDPSession(page)
  await cdp.send('Performance.enable')
  for (const count of [50, 500, 5000, 10000]) {
    for (const [ratio, missing] of [[0, false], [50, false], [100, false], [50, true], [100, true]]) {
      const name = `History${count}-${ratio}-${missing ? 'missing' : 'normal'}`
      const created = await api(page, `/admin/categories/${category}/channels`, 'POST', { name, kind: 'TEXT' })
      status(created, 201)
      const id = created.body.id
      seedHistory(owner, id, count, ratio, missing ? foreign : null)
      const initial = await api(page, `/channels/${id}/messages`)
      status(initial, 200); validateMessageIdentifiers(initial.body.messages)
      const began = performance.now()
      await channel(page, name, id)
      await expect(page.getByRole('heading', { name, exact: true })).toBeVisible()
      await expect.poll(async () => (await historyState(page)).channel).toBe(id)
      await expect.poll(async () => (await historyState(page)).count).toBe(50)
      await settle(page)
      const navigationMS = performance.now()-began
      for (let index = 0; index < Math.min(9, count/50-1); index++) await pageOlder(page)
      let anchorShift = null
      if (count > 500) {
        const control = page.getByRole('button', { name: 'Показать предыдущие сообщения', exact: true })
        await control.scrollIntoViewIfNeeded(); await settle(page)
        const anchor = await page.getByRole('log', { name: 'История сообщений' }).evaluate(list => {
          const top = list.getBoundingClientRect().top
          const row = [...list.querySelectorAll('[data-message-id]')].find(element => element.getBoundingClientRect().bottom > top)
          return { id: row.dataset.messageId, top: row.getBoundingClientRect().top }
        })
        await pageOlder(page)
        anchorShift = Math.abs((await page.locator('[data-message-id="'+anchor.id+'"]').boundingBox()).y-anchor.top)
        assert.ok(anchorShift <= 2, 'Reading anchor moved during older paging')
      }
      const state = await historyState(page)
      assert.equal(state.count, Math.min(count, 500))
      assert.ok(state.rows > 0 && state.rows < 64)
      await cdp.send('HeapProfiler.collectGarbage')
      const metrics = (await cdp.send('Performance.getMetrics')).metrics
      results.push({ count, reply_percent: ratio, unavailable_targets: missing,
        cached: state.count, rendered_rows: state.rows, anchor_shift_px: anchorShift,
        navigation_ms: Math.round(navigationMS),
        retained_heap_bytes: metrics.find(value => value.name === 'JSHeapUsedSize').value })
      console.log(`stage=history-profile-${count}-${ratio}-${missing ? 'missing' : 'normal'}-accepted`)
    }
  }
  await cdp.detach()
  return results
}
