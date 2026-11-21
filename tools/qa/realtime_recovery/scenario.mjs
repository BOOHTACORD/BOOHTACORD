import assert from 'node:assert/strict'
import { readFileSync, writeFileSync } from 'node:fs'
import { api, channel, chromium, expect, origin, status } from '../client_lifecycle/request.mjs'
import { login } from './login.mjs'
import { observe } from './observe.mjs'
import { continued } from './continued.mjs'

assert.equal(origin, 'https://localhost:4910')
const input = JSON.parse(readFileSync(process.env.QA_INPUT, 'utf8'))
const browser = await chromium.launch({ headless: true, args: ['--allow-loopback-in-peer-connection'] })
let release = () => {}, delayed = false, fulfilled = false, stage = 'login', diagnosticPage = null
try {
  const observer = await browser.newPage({ ignoreHTTPSErrors: true, viewport: { width: 1440, height: 960 } })
  const peer = await browser.newPage({ ignoreHTTPSErrors: true, viewport: { width: 1440, height: 960 } })
  diagnosticPage = observer
  observer.setDefaultTimeout(15000); peer.setDefaultTimeout(15000)
  await observer.addInitScript(observe)
  await login(observer, 'qa_admin', input.password)
  stage = 'peer-login'
  await login(peer, 'qa_admin', input.password)
  stage = 'create-owned-channel'
  const category = await api(peer, '/admin/categories', 'POST', { name: 'R1 Recovery' }); status(category, 201)
  const room = await api(peer, `/admin/categories/${category.body.id}/channels`, 'POST', { name: 'R1 Recovery', kind: 'VOICE' }); status(room, 201)
  for (const page of [observer, peer]) await channel(page, 'R1 Recovery', room.body.id)
  stage = 'sfu-join'
  await peer.getByRole('button', { name: 'Без микрофона', exact: true }).click()
  await expect(peer.getByTestId('voice-dock').locator('.voice-status')).toHaveText('Голос подключён', { timeout: 25000 })
  const roster = observer.locator('.voice-roster-preview').filter({ has: observer.locator('.voice-roster-heading') }).first()
  await expect(roster.locator('.voice-roster-member')).toHaveCount(1)
  await observer.screenshot({ path: input.directory + '/populated.png' })
  stage = 'delayed-recovery'
  const before = await observer.evaluate(() => window.__r1.opened)
  const populatedBefore = await observer.evaluate(() => window.__r1.populated)
  let held = false
  await observer.route('**/api/v1/channels', async route => {
    if (held || route.request().method() !== 'GET') return route.continue()
    held = true
    const response = await route.fetch()
    const barrier = new Promise(resolve => { release = resolve })
    delayed = true
    await barrier
    await route.fulfill({ response }); fulfilled = true
  })
  await observer.evaluate(() => { window.__r1.forceResync = true; window.__r1.socket.close() })
  await expect.poll(() => delayed).toBe(true)
  await expect.poll(() => observer.evaluate(() => window.__r1.resync)).toBeGreaterThan(0)
  await expect.poll(() => observer.evaluate(() => window.__r1.opened)).toBe(before + 1)
  await expect.poll(() => observer.evaluate(() => window.__r1.populated)).toBeGreaterThan(populatedBefore)
  const emptyBefore = await observer.evaluate(() => window.__r1.empty)
  await peer.getByTestId('voice-dock').getByRole('button', { name: 'Выйти из голосового канала', exact: true }).click()
  const fresh = await api(peer, `/admin/categories/${category.body.id}/channels`, 'POST', { name: 'R1 Fresh State', kind: 'TEXT' }); status(fresh, 201)
  await expect.poll(() => observer.evaluate(() => window.__r1.empty)).toBeGreaterThan(emptyBefore)
  await observer.evaluate(() => window.__r1.socket.close())
  await expect.poll(() => observer.evaluate(() => window.__r1.opened)).toBe(before + 2)
  await expect(roster.locator('.voice-roster-empty')).toHaveText('Пока никого нет.')
  await expect(observer.locator('.channel-button').filter({ hasText: 'R1 Fresh State' })).toBeVisible()
  assert.equal(fulfilled, false, 'Replacement recovery must finish before the old HTTP response')
  await observer.screenshot({ path: input.directory + '/new-empty-before-old-response.png' })
  release(); await expect.poll(() => fulfilled).toBe(true)
  for (let probe = 0; probe < 10; probe++) {
    await expect(roster.locator('.voice-roster-member')).toHaveCount(0)
    await expect(roster.locator('.voice-roster-empty')).toBeVisible()
    await expect(observer.locator('.channel-button').filter({ hasText: 'R1 Fresh State' })).toBeVisible()
    await observer.waitForTimeout(100)
  }
  await observer.screenshot({ path: input.directory + '/new-empty-after-old-response.png' })
  stage = 'restart-and-account-switch'
  const remaining = await continued(observer, peer, room.body.id, input, next => { stage = next })
  writeFileSync(input.directory + '/scenario.json', JSON.stringify({ status: 'PASS',
    actual_api: true, actual_sfu: true, transport: 'native browser WebSocket',
    fault: 'unmodified actual topology HTTP response delayed across two socket replacements',
    replacement_recovered_before_old_response: true, old_response_did_not_restore_participants: true,
    browser: browser.version(), opened: await observer.evaluate(() => window.__r1.opened),
    physical_media_quality: 'NOT_RUN', ...remaining }, null, 2) + '\n')
} catch (error) {
  const code = ['ERR_CONNECTION_REFUSED', 'ERR_CONNECTION_RESET', 'ERR_NETWORK_CHANGED', 'ERR_CERT_AUTHORITY_INVALID',
    'ERR_NAME_NOT_RESOLVED'].find(code => String(error?.message).includes(code)) ?? 'unclassified'
  await diagnosticPage?.screenshot({ path: input.directory + '/failure.png' }).catch(() => {})
  writeFileSync(input.directory + '/scenario.json', JSON.stringify({ status: 'FAIL', stage,
    error_class: error?.name ?? 'UnknownError', network_code: code }) + '\n')
  console.error('R1 runtime assertion failed at ' + stage)
  process.exitCode = 1
} finally {
  release()
  await browser.close()
}
