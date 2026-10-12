import assert from 'node:assert/strict'
import { api, channel, expect, openNavigation, status } from '../client_lifecycle/request.mjs'
import { owned } from './control.mjs'
import { teardown } from './teardown.mjs'
import { installRosterFailureObserver } from './roster_observer.mjs'
async function connected(page) {
  try {
    await expect(page.getByTestId('voice-dock').locator('.voice-status')).toHaveText('Голос подключён', { timeout: 22000 })
    await expect.poll(() => page.evaluate(() => window.__qaPeers.some(peer => peer.connectionState === 'connected')), { timeout: 22000 }).toBe(true)
  } catch (error) {
    // Keep only native transport state enums and counts; never SDP, tokens, identities or URLs.
    console.error('media-connect-states='+JSON.stringify(await page.evaluate(() => window.__qaPeers?.map(peer => ({
      connection: peer.connectionState, ice: peer.iceConnectionState, gathering: peer.iceGatheringState,
      signaling: peer.signalingState, local_description: Boolean(peer.localDescription),
      remote_description: Boolean(peer.remoteDescription),
    })) ?? [])))
    throw error
  }
}
export async function media(a, b, member, channelId, report, input) {
  const directory = input.directory
  let blocked = false
  const observed = { revocations: 0 }
  const chat = []
  for (const page of [a, member]) await page.addInitScript(() => {
    window.__qaPeers = []
    const Native = window.RTCPeerConnection
    window.RTCPeerConnection = new Proxy(Native, { construct(target, args) {
      const peer = Reflect.construct(target, args); window.__qaPeers.push(peer); return peer
    } })
  })
  await a.routeWebSocket(url => new URL(url).pathname === '/api/v1/realtime', socket => {
    if (blocked) { socket.close(); return }
    const server = socket.connectToServer(); chat.push({ socket, server })
    server.onMessage(message => {
      try { if (JSON.parse(String(message)).kind === 'voice.lease_revoked') observed.revocations++ } catch { /* non-JSON control frame */ }
      socket.send(message)
    })
  })
  await a.addInitScript(installRosterFailureObserver)
  await a.reload()
  await member.reload()
  const category = await api(a, '/admin/categories', 'POST', { name: 'VoiceLab' }); status(category, 201)
  const room = await api(a, `/admin/categories/${category.body.id}/channels`, 'POST', { name: 'VoiceLab', kind: 'VOICE' }); status(room, 201)
  for (const page of [a, member]) {
    await channel(page, 'VoiceLab')
    await page.getByRole('button', { name: 'Подключиться без микрофона', exact: true }).click()
    await connected(page)
  }
  await connected(a)
  blocked = true
  for (const { socket, server } of chat) { server.close(); socket.close() }
  const banner = a.getByTestId('connection-status')
  await openNavigation(a)
  await expect(banner).toBeVisible()
  await expect(banner).toContainText('Чат обновляется')
  await expect(banner).toContainText('Голос подключён')
  await connected(a)
  await a.screenshot({ path: directory+'/chat-failed-media-connected.png' })
  blocked = false
  await openNavigation(a)
  const retry = banner.getByRole('button', { name: 'Повторить связь чата' })
  const manualRetryAvailable = await retry.isVisible()
  if (manualRetryAvailable) await retry.click()
  await expect(banner).toBeHidden()
  // Both listeners now have real WebRTC transports; stop only the owned SFU.
  const rosterFailuresBefore = await a.evaluate(() => window.__qaRosterUnavailableCount)
  owned('sfu', 'stop', '$owned')
  try {
    await openNavigation(a)
    // Detection can use one 5s reconciliation period, a shared 5s snapshot deadline
    // and a bounded 3s SSE write. Check the actual event before its UI consequence.
    await expect.poll(() => a.evaluate(() => window.__qaRosterUnavailableCount), { timeout: 15000 }).toBeGreaterThan(rosterFailuresBefore)
    await expect(banner).toBeVisible()
    await expect(banner).toContainText('Состав недоступен', { timeout: 20000 })
    await expect(a.getByRole('log')).toHaveCount(0)
    assert.equal(await a.getByText('Пока никого нет.', { exact: true }).count(), 0)
    await a.screenshot({ path: directory+'/sfu-unavailable.png' })
    report.connection_status = { ws_only_failure_real_webrtc_alive: true, targeted_chat_retry: true,
      chat_retry_mode: manualRetryAvailable ? 'manual' : 'automatic',
      roster_failure_event_observed: true, sfu_failure_not_empty_room: true, last_roster_age_visible: /с\. назад/.test(await banner.innerText()) }
    assert.equal(report.connection_status.last_roster_age_visible, true)
  } finally { owned('sfu', 'start', '$owned') }
  await expect.poll(async () => (await api(a, '/voice/participants')).status, { timeout: 30000 }).toBe(200)
  await openNavigation(a)
  const refreshRoster = banner.getByRole('button', { name: 'Обновить состав' })
  const manualRosterRefreshAvailable = await refreshRoster.isVisible()
  if (manualRosterRefreshAvailable) await refreshRoster.click()
  await expect.poll(async () => await banner.count() === 0 || !(await banner.innerText()).includes('Состав недоступен')).toBe(true)
  for (const page of [a, member]) {
    const leave = page.getByTestId('voice-dock').getByRole('button', { name: 'Выйти из голосового канала', exact: true })
    if (await leave.count()) await leave.click()
  }
  await channel(a, 'Text')
  await channel(b, 'Text')
  report.connection_status.targeted_roster_retry = true
  report.connection_status.targeted_roster_retry_mode = manualRosterRefreshAvailable ? 'manual' : 'automatic'
  await teardown(a, b, channelId, input, report, observed)
}
