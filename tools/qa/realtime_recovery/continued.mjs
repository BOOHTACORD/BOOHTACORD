import assert from 'node:assert/strict'
import { api, channel, expect, status } from '../client_lifecycle/request.mjs'

export async function continued(observer, peer, room, input, step) {
  step('api-restart')
  const before = await observer.evaluate(() => ({ opened: window.__r1.opened, generation: window.__r1.generation }))
  const restart = await fetch(input.control.url, { method: 'POST',
    headers: { Authorization: 'Bearer ' + input.control.token }, signal: AbortSignal.timeout(60000) })
  assert.equal(restart.status, 204)
  await expect.poll(() => observer.evaluate(() => window.__r1.opened), { timeout: 25000 }).toBeGreaterThan(before.opened)
  await expect.poll(() => observer.evaluate(() => window.__r1.generation), { timeout: 15000 }).not.toBe(before.generation)
  const roster = observer.locator('.voice-roster-preview').first()
  await expect(roster.locator('.voice-roster-empty')).toBeVisible()
  await observer.screenshot({ path: input.directory + '/after-api-restart.png' })
  step('account-switch-setup')
  status(await api(peer, '/auth/register', 'POST', { login: 'qa_r1_member', password: input.password }), 201)
  await peer.getByRole('button', { name: 'Без микрофона', exact: true }).click()
  await expect(peer.getByTestId('voice-dock').locator('.voice-status')).toHaveText('Голос подключён', { timeout: 25000 })
  await expect(roster.locator('.voice-roster-member')).toHaveCount(1)
  let delayed = false, fulfilled = false, release = () => {}
  await observer.route('**/api/v1/channels', async route => {
    if (delayed || route.request().method() !== 'GET') return route.continue()
    const response = await route.fetch()
    const barrier = new Promise(resolve => { release = resolve })
    delayed = true
    await barrier
    await route.fulfill({ response }); fulfilled = true
  })
  try {
    await observer.evaluate(() => { window.__r1.forceResync = true; window.__r1.socket.close() })
    await expect.poll(() => delayed).toBe(true)
    await peer.getByTestId('voice-dock').getByRole('button', { name: 'Выйти из голосового канала', exact: true }).click()
    await observer.getByRole('button', { name: 'Открыть настройки профиля', exact: true }).click()
    await observer.getByRole('tab', { name: 'Безопасность', exact: true }).click()
    step('account-switch-logout')
    await observer.getByRole('button', { name: 'Выйти из аккаунта', exact: true }).click()
    await observer.getByRole('dialog', { name: 'Подтвердите выход из аккаунта' }).getByRole('button', { name: 'Выйти', exact: true }).click()
    await expect(observer.getByLabel('Логин', { exact: true })).toBeVisible()
    step('account-switch-login')
    await observer.getByLabel('Логин', { exact: true }).fill('qa_r1_member')
    await observer.getByLabel('Пароль', { exact: true }).fill(input.password)
    await observer.getByRole('button', { name: 'Войти', exact: true }).click()
    await expect(observer.getByTestId('app-shell')).toBeVisible()
    step('account-switch-empty-roster')
    await channel(observer, 'R1 Recovery', room)
    await expect(roster.locator('.voice-roster-empty')).toBeVisible()
    assert.equal(fulfilled, false)
    release(); await expect.poll(() => fulfilled).toBe(true)
    await expect(roster.locator('.voice-roster-member')).toHaveCount(0)
    await expect(observer.locator('.user-footer')).toContainText('qa_r1_member')
    await observer.screenshot({ path: input.directory + '/after-account-switch-old-response.png' })
  } finally { release() }
  return { api_process_restart: 'PASS', generation_changed_after_restart: true,
    same_page_account_switch: 'PASS', late_previous_account_topology: 'IGNORED' }
}
