const test = require('node:test')
const assert = require('node:assert/strict')
const { delivered } = require('./session.cjs')

test('requires a new session-state event on the authorized socket', () => {
  assert.equal(delivered([{ session: 1 }, { session: 1 }], 1), true)
  assert.equal(delivered([{ session: 1 }], 1), false)
  assert.equal(delivered([], 0), false)
})
