import assert from 'node:assert/strict'
import { api, expect, openNavigation, status } from '../client_lifecycle/request.mjs'
import { requests } from './requests.mjs'
export async function bursts(a, b, channelId, report, directory, baseline = false) {
  const activeChannelRoute = `#workspace/channel/${encodeURIComponent(channelId)}`
  if (new URL(a.url()).hash !== activeChannelRoute) {
    await a.evaluate(route => { window.location.hash = route }, activeChannelRoute)
    await expect.poll(() => new URL(a.url()).hash).toBe(activeChannelRoute)
  }
  await expect(a.getByRole('heading', { name: baseline ? 'WelcomeLab' : 'Text', exact: true })).toBeVisible()
  assert.equal(new URL(a.url()).hash, activeChannelRoute, 'Active browser must display the burst target channel')
  console.log('stage=critical-burst-active-channel-confirmed')
  const category = await api(a, '/admin/categories', 'POST', { name: 'HiddenLab' }); status(category, 201)
  const hidden = await api(a, `/admin/categories/${category.body.id}/channels`, 'POST', { name: 'HiddenLab', kind: 'TEXT' }); status(hidden, 201)
  console.log('stage=critical-burst-hidden-channel-created')
  await openNavigation(b)
  console.log('stage=critical-burst-navigation-open')
  await expect(b.locator('.channel-button').filter({ hasText: 'HiddenLab' })).toBeVisible()
  console.log('stage=critical-burst-hidden-channel-visible')
  await b.locator('.channel-button').filter({ hasText: 'HiddenLab' }).click()
  console.log('stage=critical-burst-hidden-channel-selected')
  const counters = [requests(a, channelId), requests(b, channelId)]
  const samples = []
  let oldest
  for (const size of [1, 20, 50]) {
    await a.waitForTimeout(300)
    counters.forEach(counter => counter.start())
    const result = await a.evaluate(async ({ channelId, size }) => {
      const rows = await Promise.all(Array.from({ length: size }, (_, index) => fetch(`/api/v1/channels/${channelId}/messages`, {
        method: 'POST', credentials: 'same-origin', headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ client_message_id: crypto.randomUUID(), body: `Synthetic burst ${size} item ${index}` }),
      }).then(async response => ({ status: response.status, body: await response.json() }))))
      return rows
    }, { channelId, size })
    result.forEach(row => status(row, 201))
    assert.ok(result.every(row => typeof row.body?.body === 'string'), 'Burst response must include a message body')
    console.log(`stage=critical-burst-${size}-posted`)
    oldest ??= result[0].body
    await expect.poll(async () => {
      const visible = await a.getByRole('log').innerText()
      return result.some(row => visible.includes(row.body.body))
    }).toBe(true)
    console.log(`stage=critical-burst-${size}-visible`)
    await expect.poll(() => counters.every(counter => counter.quiet()), { timeout: 10000 }).toBe(true)
    console.log(`stage=critical-burst-${size}-quiet`)
    const [active, hiddenResult] = counters.map(counter => counter.stop())
    console.log(`stage=critical-burst-${size}-request-metrics:${JSON.stringify({ active, hidden: hiddenResult })}`)
    assert.equal(hiddenResult.history, 0)
    assert.ok(active.history >= 1 && (baseline || active.history <= Math.max(2, size/2)), 'Unbounded protected GET burst')
    if (!baseline) assert.ok(active.max_parallel <= 1 && hiddenResult.max_parallel <= 1, 'Parallel GETs for one resource')
    samples.push({ events: size, active, hidden: hiddenResult })
  }
  if (baseline) { report.protected_refresh = { actual_api_bursts: samples }; return }
  const row = a.locator(`[data-message-id="${oldest.id}"]`)
  if (await row.count() === 0) await a.getByRole('button', { name: 'Показать предыдущие сообщения', exact: true }).click()
  await expect(row).toHaveCount(1)
  status(await api(a, `/channels/${channelId}/messages/${oldest.id}`, 'PATCH', { body: 'Synthetic old page revision', expected_revision: oldest.revision }), 200)
  await expect(row).toContainText('Synthetic old page revision')
  const revision = (await api(a, `/channels/${channelId}/messages?at=${oldest.id}&limit=20`)).body.messages.find(item => item.id === oldest.id)
  assert.equal(revision.revision, oldest.revision+1)
  status(await api(a, `/channels/${channelId}/messages/${oldest.id}`, 'DELETE'), 204)
  await expect(row).toContainText('Сообщение удалено')
  await a.screenshot({ path: directory+'/old-page-delete.png' })
  report.protected_refresh = { actual_api_bursts: samples, old_page_edit_delete: true, final_revision: revision.revision, id_only_hints_preserved: true }
}
