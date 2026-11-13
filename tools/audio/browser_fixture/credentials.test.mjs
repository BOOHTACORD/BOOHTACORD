import test from 'node:test'
import assert from 'node:assert/strict'
import { fixtureCredentials } from './credentials.mjs'

test('fixture accepts only complete custom credentials', () => {
  assert.deepEqual(fixtureCredentials({}), { key: 'devkey', secret: 'secret' })
  assert.deepEqual(fixtureCredentials({ RNNOISE_LIVEKIT_API_KEY: 'test-key', RNNOISE_LIVEKIT_API_SECRET: 'test-secret' }),
    { key: 'test-key', secret: 'test-secret' })
  assert.throws(() => fixtureCredentials({ RNNOISE_LIVEKIT_API_KEY: 'test-key' }))
  assert.throws(() => fixtureCredentials({ RNNOISE_LIVEKIT_API_SECRET: 'test-secret' }))
})
