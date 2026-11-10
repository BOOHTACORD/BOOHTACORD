const test = require('node:test')
const assert = require('node:assert/strict')
const { matches } = require('./roster_evidence.cjs')

test('requires exact distinct participants in both roster views', () => {
  assert.equal(matches(['admin', 'member'], ['member', 'admin'], ['admin', 'member']), true)
  assert.equal(matches(['admin', 'admin'], ['admin', 'member'], ['admin', 'member']), false)
  assert.equal(matches(['admin', 'member'], ['admin'], ['admin', 'member']), false)
  assert.equal(matches([], [], []), true)
})
