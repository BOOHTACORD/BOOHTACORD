import { test } from 'node:test'
import assert from 'node:assert/strict'
import { observeRosterNetwork } from './roster_network.mjs'
import { classifyVoiceJoinAlert, observeVoiceJoinNetwork, withVoiceJoinDiagnostics } from './voice_join_network.mjs'

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

test('voice join diagnostics retain only bounded categories for the owned origin', () => {
  const handlers = new Map()
  const page = {
    on(name, listener) { handlers.set(name, listener) },
    off(name, listener) { assert.equal(handlers.get(name), listener); handlers.delete(name) },
  }
  const observer = observeVoiceJoinNetwork(page)
  const request = (url, method = 'POST', reason = '') => ({
    url: () => url, method: () => method, failure: () => ({ errorText: reason }),
  })
  const lease = request('https://localhost:4810/api/v1/voice/channels/private-id/leases?token=secret')
  const credential = request('https://localhost:4810/api/v1/voice/leases/private-id/credential?token=secret')
  handlers.get('response')({ request: () => lease, status: () => 201 })
  handlers.get('response')({ request: () => credential, status: () => 503 })
  handlers.get('requestfailed')(request('https://localhost:4810/api/v1/voice/leases/private-id', 'DELETE', 'net::ERR_TIMED_OUT'))
  handlers.get('requestfailed')(request('https://foreign.test/api/v1/voice/leases/private-id/credential', 'POST', 'private secret'))
  assert.deepEqual(observer.snapshot(), [
    { stage: 'lease', status: 201 }, { stage: 'credential', status: 503 },
    { stage: 'release', failure: 'timeout' },
  ])
  assert.doesNotMatch(JSON.stringify(observer.snapshot()), /secret|private-id/)
  observer.close()
  assert.equal(handlers.size, 0)
})

test('voice join diagnostics cap events and classify unknown transport errors', () => {
  const handlers = new Map()
  const observer = observeVoiceJoinNetwork({
    on(name, fn) { handlers.set(name, fn) }, off(name) { handlers.delete(name) },
  })
  const request = {
    url: () => 'https://localhost:4810/api/v1/voice/leases/id/credential',
    method: () => 'POST', failure: () => ({ errorText: 'token=private' }),
  }
  for (let i = 0; i < 30; i++) handlers.get('requestfailed')(request)
  assert.equal(observer.snapshot().length, 20)
  assert.ok(observer.snapshot().every(event => event.failure === 'other'))
  assert.doesNotMatch(JSON.stringify(observer.snapshot()), /private/)
  observer.close()
})

test('voice join alert classification never retains raw error text', () => {
  assert.equal(classifyVoiceJoinAlert('Timed out while connecting; token=private'), 'timeout')
  assert.equal(classifyVoiceJoinAlert('Голосовой запрос отклонён: private'), 'admission')
  assert.equal(classifyVoiceJoinAlert('WebRTC peer connection failed: private'), 'media')
  assert.equal(classifyVoiceJoinAlert('token=private'), 'other')
  assert.equal(classifyVoiceJoinAlert(''), 'none')
})

test('failed voice join keeps the original error and emits no raw diagnostic data', async () => {
  const emitted = []
  const listeners = new Map()
  const page = {
    on(name, fn) { listeners.set(name, fn) }, off(name) { listeners.delete(name) },
    getByTestId() { return { locator() { return { allTextContents: async () => ['timeout token=private'] } } } },
    evaluate: async () => ['connected', 'private', 'failed'],
  }
  const original = new Error('original failure')
  await assert.rejects(withVoiceJoinDiagnostics(page, async () => { throw original }, value => emitted.push(value)), error => error === original)
  assert.deepEqual(emitted, [{ network: [], alert: 'timeout', peer_states: ['connected', 'other', 'failed'] }])
  assert.equal(listeners.size, 0)
  assert.doesNotMatch(JSON.stringify(emitted), /private/)
})

test('a diagnostic failure cannot replace the original voice join error', async () => {
  const page = {
    on() {}, off() { throw new Error('observer cleanup failed') },
    getByTestId() { throw new Error('closed page') },
  }
  const original = new Error('original failure')
  await assert.rejects(withVoiceJoinDiagnostics(page, async () => { throw original }), error => error === original)
})
