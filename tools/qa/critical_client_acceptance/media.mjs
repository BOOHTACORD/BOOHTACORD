import assert from 'node:assert/strict'
import { api, channel, expect, openNavigation, status } from '../client_lifecycle/request.mjs'
import { controlOwnedSfu } from './sfu_control.mjs'
import { teardown } from './teardown.mjs'
import { installRosterFailureObserver } from './roster_observer.mjs'
import { rosterCounters } from './roster_diagnostics.mjs'
import { observeRosterNetwork } from './roster_network.mjs'
import { observeMiniSubscriptions } from './mini_player_ui.mjs'
import { screenShareInterface } from './screen_share_ui.mjs'
import { voiceInterface, leaveVoiceInterface } from './voice_interface.mjs'
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
    window.__qaCaptureRequests = 0
    const display = navigator.mediaDevices.getDisplayMedia?.bind(navigator.mediaDevices)
    if (display) navigator.mediaDevices.getDisplayMedia = (...args) => { window.__qaCaptureRequests++; return display(...args) }
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
  const rosterNetwork = observeRosterNetwork(a)
  const miniSubscriptions = await observeMiniSubscriptions(member)
  await a.reload()
  await member.reload()
  const category = await api(a, '/admin/categories', 'POST', { name: 'VoiceLab' }); status(category, 201)
  const room = await api(a, `/admin/categories/${category.body.id}/channels`, 'POST', { name: 'VoiceLab', kind: 'VOICE' }); status(room, 201)
  for (const page of [a, member]) {
    await channel(page, 'VoiceLab')
    await page.getByRole('button', { name: 'Без микрофона', exact: true }).click()
    await connected(page)
  }
  await connected(a)
  await voiceInterface(a, input, report)
  await screenShareInterface(a, member, input, report, miniSubscriptions)
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
  // Chat recovery replaces the roster source asynchronously. Fault injection
  // must start with a live SSE stream, rather than an initial/retry HTTP fetch.
  await expect.poll(() => a.evaluate(() => window.__qaRosterTransportSource?.readyState), { timeout: 15000 }).toBe(1)
  // Both listeners have real WebRTC transports. Suspend only the owned SFU;
  // retain its network interface so this tests an SFU outage, not a host change.
  const rosterFailuresBefore = await a.evaluate(() => window.__qaRosterUnavailableCount)
  try {
    await controlOwnedSfu('pause')
    await openNavigation(a)
    // Detection can use one 5s reconciliation period, a shared 5s snapshot deadline
    // and a bounded 3s SSE write. Check the actual event before its UI consequence.
    try {
    await expect.poll(() => a.evaluate(() => window.__qaRosterUnavailableCount), { timeout: 15000 }).toBeGreaterThan(rosterFailuresBefore)
    } catch (error) {
      // Diagnose real SSE delivery without retaining URLs, payloads or identities.
      const transport = await a.evaluate(() => ({
        ...window.__qaRosterTransport,
        ready_state: window.__qaRosterTransportSource?.readyState ?? null,
        unavailable: window.__qaRosterUnavailableCount,
      }))
      const presenceStatus = (await api(a, '/voice/participants')).status
      console.error('roster-failure-diagnostics='+JSON.stringify({ ...transport, presence_status: presenceStatus,
        network: rosterNetwork(), workspace_present: await a.getByTestId('app-shell').count() > 0 }))
      // Only this journey's owned synthetic accounts are present in the capture.
      try { await a.screenshot({ path: directory+'/roster-event-failure.png' }) } catch { /* Preserve the actual event assertion. */ }
      try {
        // The fixture owns the loopback API on 4820. Never fetch production
        // telemetry, send a cookie or retain the original metric response.
        const response = await fetch('http://127.0.0.1:4820/metrics', { signal: AbortSignal.timeout(2000) })
        if (response.ok) console.error('roster-server-counters='+JSON.stringify(rosterCounters(await response.text())))
      } catch { /* Keep the original actual-event acceptance failure. */ }
      throw error
    }
    await expect(banner).toBeVisible()
    await expect(banner).toContainText('Состав недоступен', { timeout: 20000 })
    await expect(a.getByRole('log')).toHaveCount(0)
    assert.equal(await a.getByText('Пока никого нет.', { exact: true }).count(), 0)
    await a.screenshot({ path: directory+'/sfu-unavailable.png' })
    report.connection_status = { ws_only_failure_real_webrtc_alive: true, targeted_chat_retry: true,
      chat_retry_mode: manualRetryAvailable ? 'manual' : 'automatic',
      roster_failure_event_observed: true, sfu_failure_not_empty_room: true, last_roster_age_visible: /с\. назад/.test(await banner.innerText()) }
    assert.equal(report.connection_status.last_roster_age_visible, true)
  } finally { await controlOwnedSfu('unpause') }
  await expect.poll(async () => (await api(a, '/voice/participants')).status, { timeout: 30000 }).toBe(200)
  await openNavigation(a)
  const refreshRoster = banner.getByRole('button', { name: 'Обновить состав' })
  const manualRosterRefreshAvailable = await refreshRoster.isVisible()
  if (manualRosterRefreshAvailable) await refreshRoster.click()
  await expect.poll(async () => await banner.count() === 0 || !(await banner.innerText()).includes('Состав недоступен')).toBe(true)
  await leaveVoiceInterface(a, input, report)
  for (const page of [member]) {
    const leave = page.getByTestId('voice-dock').getByRole('button', { name: 'Выйти из голосового канала', exact: true })
    if (await leave.count()) await leave.click()
  }
  await channel(a, 'Text')
  await channel(b, 'Text')
  report.connection_status.targeted_roster_retry = true
  report.connection_status.targeted_roster_retry_mode = manualRosterRefreshAvailable ? 'manual' : 'automatic'
  await teardown(a, b, channelId, input, report, observed)
}
