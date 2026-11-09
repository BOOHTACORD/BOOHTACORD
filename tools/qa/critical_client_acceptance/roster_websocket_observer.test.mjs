import { test } from 'node:test'
import assert from 'node:assert/strict'
import { installRosterFailureObserver } from './roster_observer.mjs'

test('observes only authenticated WebSocket roster failures without retaining payload', () => {
  class Socket {
    constructor(...args) { this.args = args; this.listeners = new Map(); this.readyState = 0 }
    addEventListener(kind, listener) { this.listeners.set(kind, listener) }
    close() { this.readyState = 3 }
    emit(kind, data) { this.listeners.get(kind)?.({ data }) }
  }
  const browser = { WebSocket: Socket, location: { href: 'https://localhost:4810/', host: 'localhost:4810' } }
  installRosterFailureObserver(browser)
  const owned = new browser.WebSocket('wss://localhost:4810/api/v1/realtime?capabilities=voice_roster_v1')
  const guest = new browser.WebSocket('wss://localhost:4810/api/v1/public/realtime')
  const foreign = new browser.WebSocket('wss://foreign.test/api/v1/realtime')
  owned.emit('open')
  owned.emit('message', JSON.stringify({ kind: 'voice.roster.unavailable', payload: { private: 'do-not-store' } }))
  guest.emit('message', JSON.stringify({ kind: 'voice.roster.unavailable' }))
  foreign.emit('message', JSON.stringify({ kind: 'voice.roster.unavailable' }))
  assert.equal(browser.__qaRosterUnavailableCount, 1)
  assert.equal(browser.__qaRosterTransport.created, 1)
  assert.equal(browser.__qaRosterTransport.opened, 1)
  assert.ok(!JSON.stringify(browser.__qaRosterTransport).includes('do-not-store'))
  owned.close()
  assert.equal(browser.__qaRosterTransport.latest_closed_by_client, true)
})

test('old socket closure cannot mark a replacement as client-closed', () => {
  class Socket {
    constructor() { this.listeners = new Map(); this.readyState = 0 }
    addEventListener(kind, listener) { this.listeners.set(kind, listener) }
    close() { this.readyState = 3 }
    emit(kind, data) { this.listeners.get(kind)?.({ data }) }
  }
  const browser = { WebSocket: Socket, location: { href: 'https://localhost:4810/', host: 'localhost:4810' } }
  installRosterFailureObserver(browser)
  const first = new browser.WebSocket('wss://localhost:4810/api/v1/realtime')
  const second = new browser.WebSocket('wss://localhost:4810/api/v1/realtime')
  first.close()
  assert.equal(browser.__qaRosterTransport.closed_by_client, 1)
  assert.equal(browser.__qaRosterTransport.latest_closed_by_client, false)
  second.emit('error')
  second.emit('message', 'not-json')
  assert.equal(browser.__qaRosterTransport.failed, 1)
  assert.equal(browser.__qaRosterUnavailableCount, 0)
  second.close()
  assert.equal(browser.__qaRosterTransport.latest_closed_by_client, true)
})
