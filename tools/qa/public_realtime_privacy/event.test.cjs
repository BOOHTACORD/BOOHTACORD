const test = require('node:test')
const assert = require('node:assert/strict')
const { allowed } = require('./event.cjs')

const base = { event_id: 'id', occurred_at: 'date', kind: 'connection.ready', payload: {} }
test('public feed accepts only the fixed maintenance envelope', () => {
  assert.equal(allowed(base), true)
  const snapshot = { ...base, kind: 'maintenance.snapshot', payload: { version: 1, generation: 'g', revision: 1, active: false } }
  assert.equal(allowed(snapshot), true)
  assert.equal(allowed({ ...snapshot, payload: { ...snapshot.payload, account_id: 'private' } }), false)
  assert.equal(allowed({ ...base, kind: 'voice.roster.snapshot' }), false)
  assert.equal(allowed({ ...base, kind: 'direct_message.message_created' }), false)
  assert.equal(allowed({ ...base, account_id: 'private' }), false)
  assert.equal(allowed({ ...base, payload: [] }), false)
})
