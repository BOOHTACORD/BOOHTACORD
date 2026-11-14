import { voiceMemberProfile } from '../client_lifecycle/member_profile.mjs'
import { api, channel, expect, openNavigation, status } from '../client_lifecycle/request.mjs'
import { rosterOutage } from './roster_outage.mjs'
import { teardown } from './teardown.mjs'
import { installRosterFailureObserver } from './roster_observer.mjs'
import { observeRosterNetwork } from './roster_network.mjs'
import { observeMiniSubscriptions } from './mini_player_ui.mjs'
import { screenShareInterface } from './screen_share_ui.mjs'
import { voiceInterface, leaveVoiceInterface } from './voice_interface.mjs'
import { connected } from './media_connected.mjs'
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
  await voiceMemberProfile(a, member, input, report)
  await voiceInterface(a, input, report)
  await screenShareInterface(a, member, input, report, miniSubscriptions)
  console.log('stage=screen-share-lifecycle-returned')
  blocked = true
  for (const { socket, server } of chat) { server.close(); socket.close() }
  console.log('stage=chat-recovery-fault-injected')
  const banner = a.getByTestId('connection-status')
  await openNavigation(a)
  console.log('stage=chat-recovery-navigation-open')
  await expect(banner).toBeVisible()
  console.log('stage=chat-recovery-banner-visible')
  await expect(banner).toContainText('Чат обновляется')
  await expect(banner).toContainText('Голос подключён')
  console.log('stage=chat-recovery-status-visible')
  await connected(a)
  console.log('stage=voice-retained-during-chat-recovery')
  await a.screenshot({ path: directory+'/chat-failed-media-connected.png' })
  blocked = false
  await openNavigation(a)
  console.log('stage=chat-recovery-navigation-reopened')
  const retry = banner.getByRole('button', { name: 'Повторить связь чата' })
  const manualRetryAvailable = await retry.isVisible()
  if (manualRetryAvailable) await retry.click()
  await expect(banner).toBeHidden()
  console.log('stage=chat-recovery-retried')
  // Chat recovery replaces the shared application socket asynchronously.
  // Fault injection starts only after that socket is open.
  await expect.poll(() => a.evaluate(() => window.__qaRosterTransportSource?.readyState), { timeout: 15000 }).toBe(1)
  console.log('stage=roster-transport-restored')
  const manualRosterRefreshAvailable = await rosterOutage(a, banner, rosterNetwork, directory, manualRetryAvailable, report)
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
