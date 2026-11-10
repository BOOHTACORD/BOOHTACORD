const test = require('node:test')
const assert = require('node:assert/strict')
const { statusMatches } = require('./microphone.cjs')

test('requires the intended mute state in both roster views', () => {
  assert.equal(statusMatches('Микрофон выключен', 'Микрофон выключен', true), true)
  assert.equal(statusMatches('Говорит', 'В голосовом канале', false), true)
  assert.equal(statusMatches('Микрофон недоступен', 'Микрофон выключен', true), false)
  assert.equal(statusMatches('Микрофон выключен', 'В голосовом канале', true), false)
})
