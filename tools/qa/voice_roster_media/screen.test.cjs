const test = require('node:test')
const assert = require('node:assert/strict')
const { publishedInBoth, decoded } = require('./screen.cjs')

test('requires screen status to match in both roster views', () => {
  assert.equal(publishedInBoth(1, 1, true), true)
  assert.equal(publishedInBoth(0, 0, false), true)
  assert.equal(publishedInBoth(1, 0, true), false)
  assert.equal(publishedInBoth(2, 2, true), false)
  assert.equal(publishedInBoth(1, 1, false), false)
})

test('requires actual decoded video frames', () => {
  assert.equal(decoded({ width: 640, frames: 1 }), true)
  assert.equal(decoded({ width: 640, frames: 0 }), false)
  assert.equal(decoded({ width: 0, frames: 10 }), false)
})
