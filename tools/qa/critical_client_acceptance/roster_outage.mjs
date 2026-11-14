import assert from 'node:assert/strict'
import { api, expect, openNavigation } from '../client_lifecycle/request.mjs'
import { controlOwnedSfu } from './sfu_control.mjs'
import { diagnoseRosterFailure } from './roster_failure_diagnostics.mjs'

// Pause the owned SFU without removing its interface or changing the assertions.
export async function rosterOutage(a, banner, rosterNetwork, directory, manualRetryAvailable, report) {
  const rosterFailuresBefore = await a.evaluate(() => window.__qaRosterUnavailableCount)
  try {
    await controlOwnedSfu('pause')
    console.log('stage=roster-sfu-paused')
    await openNavigation(a)
    // Detection includes reconciliation, snapshot deadline and bounded delivery.
    try {
      await expect.poll(() => a.evaluate(() => window.__qaRosterUnavailableCount), { timeout: 15000 }).toBeGreaterThan(rosterFailuresBefore)
    } catch (error) {
      await diagnoseRosterFailure(a, rosterNetwork, directory)
      throw error
    }
    console.log('stage=roster-failure-event-observed')
    await expect(banner).toBeVisible()
    console.log('stage=roster-failure-banner-visible')
    await expect(banner).toContainText('Состав недоступен', { timeout: 20000 })
    console.log('stage=roster-failure-copy-visible')
    await expect(a.getByRole('log')).toHaveCount(0)
    assert.equal(await a.getByText('Пока никого нет.', { exact: true }).count(), 0)
    await a.screenshot({ path: directory+'/sfu-unavailable.png' })
    report.connection_status = { ws_only_failure_real_webrtc_alive: true, targeted_chat_retry: true,
      chat_retry_mode: manualRetryAvailable ? 'manual' : 'automatic',
      roster_failure_event_observed: true, sfu_failure_not_empty_room: true, last_roster_age_visible: /с\. назад/.test(await banner.innerText()) }
    assert.equal(report.connection_status.last_roster_age_visible, true)
    console.log('stage=roster-failure-ui-accepted')
  } finally { await controlOwnedSfu('unpause') }
  await expect.poll(async () => (await api(a, '/voice/participants')).status, { timeout: 30000 }).toBe(200)
  console.log('stage=roster-sfu-restored')
  await openNavigation(a)
  const refreshRoster = banner.getByRole('button', { name: 'Обновить состав' })
  const manualRosterRefreshAvailable = await refreshRoster.isVisible()
  if (manualRosterRefreshAvailable) await refreshRoster.click()
  await expect.poll(async () => await banner.count() === 0 || !(await banner.innerText()).includes('Состав недоступен')).toBe(true)
  return manualRosterRefreshAvailable
}
