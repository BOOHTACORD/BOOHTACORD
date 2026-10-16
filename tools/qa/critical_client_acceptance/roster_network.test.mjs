import { test } from 'node:test'
import assert from 'node:assert/strict'
import { observeRosterNetwork } from './roster_network.mjs'

function fixture() {
  const events = new Map()
  const page = { on(name, listener) { events.set(name, listener) } }
  return { events, read: observeRosterNetwork(page) }
}
test('retains only fixed network failure enums and numeric response status', () => {
  const { events, read } = fixture()
  const url = () => 'https://localhost:4810/api/v1/voice/rosters/events?private=secret'
  events.get('response')({ url, status: () => 200 })
  events.get('requestfailed')({ url, failure: () => ({ errorText: 'net::ERR_HTTP2_PROTOCOL_ERROR' }) })
  events.get('requestfailed')({ url, failure: () => ({ errorText: 'private secret error' }) })
  assert.deepEqual(read(), { status: 200, failed: { http2_protocol: 1, other: 1 } })
  assert.ok(!JSON.stringify(read()).includes('secret'))
})
test('ignores foreign hosts, other routes and invalid URLs before inspecting failures', () => {
  const { events, read } = fixture()
  for (const value of ['https://foreign.test/api/v1/voice/rosters/events', 'https://localhost:4810/api/v1/messages', 'invalid']) {
    events.get('requestfailed')({ url: () => value, failure() { assert.fail('Foreign failure must not be read') } })
    events.get('response')({ url: () => value, status() { assert.fail('Foreign response must not be read') } })
  }
  assert.deepEqual(read(), { status: null, failed: {} })
})
