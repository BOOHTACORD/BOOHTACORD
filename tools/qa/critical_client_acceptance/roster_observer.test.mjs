import { test } from 'node:test'
import assert from 'node:assert/strict'
import { installRosterFailureObserver } from './roster_observer.mjs'

function fixture() {
  class NativeEventSource {
    constructor(...args) { this.args = args; this.listeners = new Map(); this.readyState = 0 }
    addEventListener(name, listener) { this.listeners.set(name, listener) }
    close() { this.closed = true; this.readyState = 2 }
    emit(name) { this.readyState = name === 'open' ? 1 : name === 'error' ? 0 : this.readyState; this.listeners.get(name)?.({ data: 'unused private payload' }) }
  }
  const browser = { EventSource: NativeEventSource, location: { href: 'https://localhost:4810/' } }
  installRosterFailureObserver(browser)
  return { browser, NativeEventSource }
}

test('observes actual roster failure across replacement sources without changing transport', () => {
  const { browser, NativeEventSource } = fixture()
  const options = { withCredentials: true }
  const first = new browser.EventSource('/api/v1/voice/rosters/events', options)
  assert.ok(first instanceof NativeEventSource)
  assert.deepEqual(first.args, ['/api/v1/voice/rosters/events', options])
  first.emit('message')
  assert.equal(browser.__qaRosterUnavailableCount, 0)
  first.emit('roster-unavailable')
  first.close()
  const replacement = new browser.EventSource('https://localhost:4810/api/v1/voice/rosters/events')
  replacement.emit('roster-unavailable')
  assert.equal(first.closed, true)
  assert.equal(browser.__qaRosterUnavailableCount, 2)
})

test('unrelated event streams cannot satisfy the roster failure wait', () => {
  const { browser } = fixture()
  const unrelated = new browser.EventSource('/api/v1/maintenance/events')
  unrelated.emit('roster-unavailable')
  assert.equal(browser.__qaRosterUnavailableCount, 0)
  assert.equal(unrelated.listeners.size, 0)
})

test('failure diagnostics keep only bounded transport counters and native state', () => {
  const { browser } = fixture()
  const first = new browser.EventSource('/api/v1/voice/rosters/events')
  first.emit('open')
  first.emit('error')
  first.emit('roster-unavailable')
  new browser.EventSource('/api/v1/maintenance/events')
  assert.deepEqual(browser.__qaRosterTransport, { created: 1, opened: 1, failed: 1 })
  assert.equal(browser.__qaRosterUnavailableCount, 1)
  assert.equal(browser.__qaRosterTransportSource, first)
  assert.equal(browser.__qaRosterTransportSource.readyState, 0)
  assert.ok(!JSON.stringify(browser.__qaRosterTransport).includes('private payload'))
})
