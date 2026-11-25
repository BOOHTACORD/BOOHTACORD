import assert from 'node:assert/strict'
import { test } from 'node:test'
import { fixtureSQL, seedHistory, validateMessageIdentifiers } from './seed.mjs'
const channel = '10000000-0000-4000-8000-000000000001'
test('fixture rejects unbounded data and SQL fragments before database access', () => {
  for (const count of [-1, 0, 999999]) assert.throws(() => fixtureSQL(channel, count, 50))
  for (const ratio of [-1, 1, 101]) assert.throws(() => fixtureSQL(channel, 1000, ratio))
  assert.throws(() => fixtureSQL(channel+"'; SELECT 1;--", 1000, 50))
  assert.throws(() => fixtureSQL(channel, 1000, 50, 'not-a-uuid'))
})
test('unowned or missing namespace cannot reach Docker', () => {
  for (const owner of [undefined, '', 'production-db', 'qa-client-1234;id'])
    assert.throws(() => seedHistory(owner, channel, 1000, 50))
})
test('acceptance rejects non-v4 fixture messages before calling the browser scenario', () => {
  validateMessageIdentifiers([{ id: channel, client_message_id: channel }])
  for (const id of ['10000000-0000-0000-8000-000000000001', '10000000-0000-4000-0000-000000000001']) {
    assert.throws(() => validateMessageIdentifiers([{ id, client_message_id: channel }]))
    assert.throws(() => validateMessageIdentifiers([{ id: channel, client_message_id: id }]))
  }
})
