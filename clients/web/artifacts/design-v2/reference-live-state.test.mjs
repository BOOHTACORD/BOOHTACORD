import assert from 'node:assert/strict'
import test from 'node:test'
import { installReferenceTransports } from './reference-live-state.mjs'

test('reference sockets emit typed public and authenticated events only', async () => {
  const previous = globalThis.window
  globalThis.window = {}
  try {
    await installReferenceTransports({ addInitScript: async (callback, options) => callback(options) })
    const publicEvents = [], authEvents = []
    const guest = new window.WebSocket('wss://localhost/api/v1/public/realtime')
    const member = new window.WebSocket('wss://localhost/api/v1/realtime?capabilities=maintenance_v1,voice_roster_v1')
    guest.onmessage = event => publicEvents.push(JSON.parse(event.data))
    member.onmessage = event => authEvents.push(JSON.parse(event.data))
    await new Promise(resolve => setTimeout(resolve, 50))
    assert.deepEqual(publicEvents.map(event => event.kind), ['connection.ready', 'maintenance.snapshot'])
    assert.deepEqual(authEvents.map(event => event.kind), ['connection.ready', 'maintenance.snapshot', 'voice.roster.unavailable'])
    for (const event of [...publicEvents, ...authEvents]) {
      assert.match(event.event_id, /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-8[0-9a-f]{3}-[0-9a-f]{12}$/)
    }
    assert.deepEqual(Object.keys(publicEvents[1].payload).sort(), ['active', 'generation', 'revision', 'version'])
    assert.equal(window.EventSource, undefined)
    guest.close(); member.close()
  } finally {
    globalThis.window = previous
  }
})

test('closing a reference socket suppresses late events', async () => {
  const previous = globalThis.window
  globalThis.window = {}
  try {
    await installReferenceTransports({ addInitScript: async (callback, options) => callback(options) })
    const socket = new window.WebSocket('wss://localhost/api/v1/public/realtime')
    let events = 0
    socket.onmessage = () => events++
    socket.close()
    await new Promise(resolve => setTimeout(resolve, 20))
    assert.equal(events, 0)
  } finally {
    globalThis.window = previous
  }
})

test('reference socket can keep maintenance unknown for UI fault scenarios', async () => {
  const previous = globalThis.window
  globalThis.window = {}
  try {
    await installReferenceTransports({ addInitScript: async (callback, options) => callback(options) }, { maintenanceUnknown: true })
    const socket = new window.WebSocket('wss://localhost/api/v1/public/realtime')
    let events = 0
    socket.onmessage = () => events++
    await new Promise(resolve => setTimeout(resolve, 20))
    assert.equal(events, 0)
    socket.close()
  } finally {
    globalThis.window = previous
  }
})
