import assert from 'node:assert/strict'
import { expect } from '../request.mjs'
import { discoveryPort } from './port.mjs'
import { discoveryGap } from './discovery.mjs'

export async function rejoinThroughDiscoveryGap(page, report) {
  const port = await discoveryPort()
  const credentials = [], leases = [], failures = []
  let gated = false, restored, setupFailure
  const pattern = '**/api/v1/voice/leases/*/credential'
  const gate = async route => {
    if (gated) return route.fallback()
    gated = true
    try {
      const response = await route.fetch({ maxRedirects: 0, maxRetries: 0 })
      assert.equal(response.status(), 200, 'Initial credential was rejected')
      restored = await discoveryGap(port)
      await route.fulfill({ response })
    } catch (error) { setupFailure = error; await route.abort() }
  }
  const response = value => {
    const request = value.request(), path = new URL(value.url()).pathname
    if (request.method() !== 'POST') return
    if (/^\/api\/v1\/voice\/channels\/[^/]+\/leases$/.test(path)) leases.push(value.status())
    if (/^\/api\/v1\/voice\/leases\/[^/]+\/credential$/.test(path)) credentials.push({ path, status: value.status() })
  }
  const socket = value => {
    if (!new URL(value.url()).pathname.startsWith('/qa-sfu/rtc')) return
    value.on('socketerror', error => {
      if (/Unexpected (?:response code|server response): 500/.test(error)) failures.push(500)
    })
  }
  page.on('response', response); page.on('websocket', socket)
  await page.route(pattern, gate)
  try {
    await page.getByRole('button', { name: 'Без микрофона', exact: true }).click()
    await expect(page.getByTestId('voice-dock').locator('.voice-status')).toHaveText('Голос подключён', { timeout: 30000 })
    assert.equal(failures.length, 1, 'The initial real SFU handshake must fail with HTTP 500')
    assert.deepEqual(leases, [201], 'Recovery must not acquire/transfer a second lease')
    assert.deepEqual(credentials.map(value => value.status), [200, 200])
    assert.equal(credentials[0].path, credentials[1].path, 'Recovery must revalidate the exact lease')
    await restored()
    report.web_rejoin_discovery = { actual_api_sfu: true, initial_handshake_status: 500,
      owned_registry_gap_verified: true, heartbeat_restored_discovery: true,
      lease_acquisitions: leases.length, credential_requests: credentials.length,
      same_lease_revalidated: true, no_lease_transfer: true, automatic_rejoin: true }
    console.log('stage=web-rejoin-discovery-recovered')
  } catch (error) {
    console.error('web-rejoin-diagnostics='+JSON.stringify({ gap_applied: Boolean(restored),
      handshake_500_count: failures.length, lease_statuses: leases,
      credential_statuses: credentials.map(value => value.status), setup_failed: Boolean(setupFailure) }))
    throw setupFailure ?? error
  }
  finally {
    await page.unroute(pattern, gate)
    page.off('response', response); page.off('websocket', socket)
    await restored?.().catch(() => undefined)
  }
}
