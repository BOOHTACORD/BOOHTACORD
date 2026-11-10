const test = require('node:test')
const assert = require('node:assert/strict')
const { received } = require('./audio.cjs')

test('requires increasing inbound audio and one live playback element', () => {
  assert.equal(received(3, { packets: 4, elements: 1 }), true)
  assert.equal(received(3, { packets: 3, elements: 1 }), false)
  assert.equal(received(3, { packets: 4, elements: 2 }), false)
  assert.equal(received(3, { packets: 4, elements: 0 }), false)
})
