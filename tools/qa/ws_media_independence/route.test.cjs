const test = require('node:test')
const assert = require('node:assert/strict')
const { applicationSocket, handle } = require('./route.cjs')

test('fault targets only the owned application socket', () => {
  assert.equal(applicationSocket(new URL('wss://localhost:4810/api/v1/realtime?capabilities=test')), true)
  for (const value of ['wss://localhost:4810/qa-sfu', 'wss://other:4810/api/v1/realtime',
    'wss://localhost:4810/api/v1/public/realtime']) assert.equal(applicationSocket(new URL(value)), false)
})

test('blocked attempts close while recovery forwards to the real server', () => {
  const calls = []
  const server = { close: () => calls.push('server_closed') }
  const route = { close: () => calls.push('closed'), connectToServer: () => { calls.push('forwarded'); return server } }
  const state = { blocked: true, attempts: 0, bridges: [] }
  handle(route, state); state.blocked = false; handle(route, state)
  assert.deepEqual(calls, ['closed', 'forwarded'])
  assert.equal(state.attempts, 1)
  assert.deepEqual(state.bridges, [{ route, server }])
})
