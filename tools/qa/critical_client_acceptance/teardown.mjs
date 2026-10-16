import assert from 'node:assert/strict'
import { owned } from './control.mjs'
import { api, channel, expect, login, security, status } from '../client_lifecycle/request.mjs'
async function join(page) {
  await channel(page, 'VoiceLab')
  await page.getByRole('button', { name: 'Без микрофона', exact: true }).click()
  await expect(page.getByTestId('voice-dock').locator('.voice-status')).toHaveText('Голос подключён', { timeout: 22000 })
}
async function mediaClosed(page) {
  try {
    await expect.poll(() => page.evaluate(() => window.__qaPeers.every(peer => peer.connectionState !== 'connected'))).toBe(true)
  } catch (error) {
    console.error('media-close-state-counts='+JSON.stringify(await page.evaluate(() => Object.groupBy(window.__qaPeers.map(peer => peer.connectionState), state => state))))
    throw error
  }
}
export async function teardown(a, b, channelId, input, report, observed) {
  await join(a)
  await channel(a, 'Text')
  let release, waiting = false
  const routed = []
  const held = new Promise(resolve => { release = resolve })
  const pattern = `**/api/v1/channels/${channelId}/messages*`
  await a.route(pattern, route => {
    const work = (async () => {
      if (route.request().method() === 'GET') { waiting = true; await held }
      try { await route.continue() }
      catch (error) { if (!error.message.includes('Route is already handled') && !error.message.includes('has been closed')) throw error }
    })()
    routed.push(work)
    return work
  })
  try {
    status(await api(b, `/channels/${channelId}/messages`, 'POST', {
      client_message_id: crypto.randomUUID(), body: 'Synthetic blocked refresh',
    }), 201)
    await expect.poll(() => waiting).toBe(true)
    const account = (await api(b, '/auth/session')).body.account_id
    const previousRevocations = observed.revocations
    const started = Date.now()
    const kick = await api(b, `/admin/accounts/${account}/voice-kick`, 'POST')
    status(kick, 200)
    assert.equal(kick.body.revoked_leases, 1)
    // Native notification worker polls every 15 seconds; client teardown is checked separately.
    try {
      await expect.poll(() => observed.revocations, { timeout: 20000 }).toBeGreaterThan(previousRevocations)
    } catch (error) {
      // Aggregate counters from the owned disposable DB only; no lease/account IDs or tokens.
      let outbox = 'UNAVAILABLE'
      try {
        outbox = JSON.parse(owned('db', 'exec', '$owned', 'psql', '-U', 'qa', '-d', 'qa', '-Atc',
          "SELECT json_build_object('pending', count(*) FILTER (WHERE notification_emitted_at IS NULL), 'claimed', count(*) FILTER (WHERE notification_claim_token IS NOT NULL), 'emitted', count(*) FILTER (WHERE notification_emitted_at IS NOT NULL), 'pending_kicks', count(*) FILTER (WHERE notification_emitted_at IS NULL AND lease.revocation_reason = 'KICK'), 'oldest_pending_seconds', coalesce(floor(max(extract(epoch FROM now() - revocation.requested_at)) FILTER (WHERE notification_emitted_at IS NULL)), 0)) FROM voice_sfu_revocations AS revocation JOIN voice_leases AS lease ON lease.id = revocation.lease_id").toString())
      } catch { /* Keep the original acceptance failure. */ }
      let connected = 'UNAVAILABLE'
      try { connected = await a.evaluate(() => window.__qaPeers.filter(peer => peer.connectionState === 'connected').length) }
      catch { /* A closed page must not replace the original failure. */ }
      console.error('lease-notification-diagnostics='+JSON.stringify({ outbox,
        observed_hints: observed.revocations-previousRevocations, connected_transports: connected,
      }))
      throw error
    }
    const received = Date.now()
    await expect(a.getByTestId('voice-dock')).not.toHaveClass(/connected/, { timeout: 2000 })
    await mediaClosed(a)
    report.connection_status.lease_revoke_during_blocked_rest = true
    report.connection_status.revoke_timing = { server_hint_wait_ms: received-started, local_disconnect_after_hint_ms: Date.now()-received }
  } finally { release(); await Promise.all(routed); await a.unroute(pattern) }
  await join(a)
  await security(a)
  await a.getByRole('button', { name: 'Выйти из аккаунта', exact: true }).click()
  const logoutConfirmation = a.getByRole('dialog', { name: 'Подтвердите выход из аккаунта' })
  await expect(logoutConfirmation).toBeVisible()
  await logoutConfirmation.getByRole('button', { name: 'Выйти', exact: true }).click()
  await expect(a.locator('.authentication-page')).toBeVisible({ timeout: 15000 })
  await mediaClosed(a)
  await expect(a.getByTestId('connection-status')).toHaveCount(0)
  await expect(a.getByTestId('voice-dock')).toHaveCount(0)
  report.connection_status.logout_clears_voice_and_roster = true
  await login(a, 'qa_admin', input.password)
}
export async function prepareSessionRevoke(page) {
  await page.addInitScript(() => {
    window.__qaPeers = []
    const Native = window.RTCPeerConnection
    window.RTCPeerConnection = new Proxy(Native, { construct(target, args) {
      const peer = Reflect.construct(target, args); window.__qaPeers.push(peer); return peer
    } })
  })
  await page.reload()
  await join(page)
  await expect.poll(() => page.evaluate(() => window.__qaPeers.some(peer => peer.connectionState === 'connected'))).toBe(true)
}
export async function checkSessionRevoke(page, report) {
  await expect(page.locator('.authentication-page')).toBeVisible({ timeout: 15000 })
  await mediaClosed(page)
  await expect(page.getByTestId('connection-status')).toHaveCount(0)
  await expect(page.getByTestId('voice-dock')).toHaveCount(0)
  report.connection_status.session_revoke_clears_chat_voice_roster = true
}
