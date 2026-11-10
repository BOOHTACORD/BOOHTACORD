const test = require('node:test')
const assert = require('node:assert/strict')
const { delivered } = require('./dm.cjs')

test('requires a newly observed private-message hint', () => {
  assert.equal(delivered([{ dm: 1 }, { dm: 2 }], 2), true)
  assert.equal(delivered([{ dm: 1 }, { dm: 1 }], 2), false)
  assert.equal(delivered([], 0), false)
})
