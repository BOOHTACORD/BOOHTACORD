import { test } from 'node:test'
import assert from 'node:assert/strict'
import { observeRosterNetwork } from './roster_network.mjs'

function fixture() {
  const events = new Map()
  const page = { on(name, listener) { events.set(name, listener) } }
  return { events, read: observeRosterNetwork(page) }
}

test('retains bounded failure enums for the owned application socket only', () => {
  const { events, read } = fixture()
  const handlers = new Map()
  events.get('websocket')({ url: () => 'wss://localhost:4810/api/v1/realtime?private=secret', on: (name, fn) => handlers.set(name, fn) })
  handlers.get('socketerror')('net::ERR_CONNECTION_RESET')
  handlers.get('socketerror')('private secret error')
  assert.deepEqual(read(), { status: null, failed: { reset: 1, other: 1 } })
  assert.ok(!JSON.stringify(read()).includes('secret'))
})

test('ignores other sockets and HTTP endpoints before reading details', () => {
  const { events, read } = fixture()
  for (const value of ['wss://foreign.test/api/v1/realtime', 'wss://localhost:4810/api/v1/public/realtime', 'invalid']) {
    events.get('websocket')({ url: () => value, on() { assert.fail('foreign socket must not be observed') } })
    events.get('requestfailed')({ url: () => value, failure() { assert.fail('foreign failure must not be read') } })
  }
  assert.deepEqual(read(), { status: null, failed: {} })
})

test('retains only numeric upgrade status and bounded request failure codes', () => {
  const { events, read } = fixture()
  const url = () => 'https://localhost:4810/api/v1/realtime?private=secret'
  events.get('response')({ url, status: () => 503 })
  events.get('requestfailed')({ url, failure: () => ({ errorText: 'net::ERR_TIMED_OUT' }) })
  assert.deepEqual(read(), { status: 503, failed: { timeout: 1 } })
})
