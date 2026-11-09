import { test } from 'node:test'
import assert from 'node:assert/strict'
import { installObserver } from './observer.mjs'

test('tracks authorized socket snapshots, failures and replacement without payload logging', () => {
  class Socket {
    constructor() { this.listeners = new Map() }
    addEventListener(name, listener) { this.listeners.set(name, listener) }
    close() { this.emit('close', { code: 1000 }) }
    emit(name, value = {}) { this.listeners.get(name)?.(value) }
  }
  const browser = { WebSocket: Socket, location: { href: 'https://localhost:5070/', host: 'localhost:5070' } }
  installObserver(browser)
  const first = new browser.WebSocket('wss://localhost:5070/api/v1/realtime')
  const guest = new browser.WebSocket('wss://localhost:5070/api/v1/public/realtime')
  guest.emit('message', { data: JSON.stringify({ kind: 'voice.roster.snapshot', payload: { channels: [] } }) })
  first.emit('message', { data: JSON.stringify({ kind: 'voice.roster.snapshot', payload: { channels: [{ channel_id: 'fixture', participants: [{ microphone_muted: true, screen_sharing: false, display_name: 'not-retained' }] }] } }) })
  assert.equal(browser.__qaRoster.snapshots, 1)
  assert.deepEqual(browser.__qaRoster.counts, [{ id: 'fixture', count: 1, muted: 1, sharing: 0 }])
  assert.ok(!JSON.stringify(browser.__qaRoster).includes('not-retained'))
  first.emit('message', { data: JSON.stringify({ kind: 'voice.roster.unavailable', payload: {} }) })
  assert.equal(browser.__qaRoster.lastEvent, 'unavailable')
  first.close()
  const replacement = new browser.WebSocket('wss://localhost:5070/api/v1/realtime')
  first.emit('message', { data: JSON.stringify({ kind: 'voice.roster.snapshot', payload: { channels: [] } }) })
  assert.equal(browser.__qaRoster.snapshots, 1)
  assert.equal(browser.__qaRoster.active, 1)
  replacement.close()
  assert.equal(browser.__qaRoster.active, 0)
  assert.equal(browser.__qaRoster.maxActive, 1)
})
