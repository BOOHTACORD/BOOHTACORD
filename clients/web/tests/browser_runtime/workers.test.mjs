import assert from 'node:assert/strict'
import { test } from 'node:test'
import { browserRuntime } from './workers.ts'

const pool = { GITHUB_ACTIONS: 'true', RUNNER_ENVIRONMENT: 'self-hosted', RUNNER_OS: 'Linux', BOOHTACORD_EPHEMERAL_GUEST: 'true' }
const serial = { workers: 1, fullyParallel: false }

test('the four-CPU disposable Linux pool uses two independent browser workers within each file', () => {
  assert.deepEqual(browserRuntime(pool, 4), { workers: 2, fullyParallel: true })
})
test('local and hosted runs preserve their serial execution', () => {
  assert.deepEqual(browserRuntime({}, 4), serial)
  assert.deepEqual(browserRuntime({ ...pool, RUNNER_ENVIRONMENT: 'github-hosted' }, 4), serial)
})
test('every pool marker is required and other native platforms remain serial', () => {
  for (const key of Object.keys(pool)) {
    const missing = { ...pool }; delete missing[key]
    assert.deepEqual(browserRuntime(missing, 4), serial, key)
  }
  for (const os of ['Windows', 'macOS']) assert.deepEqual(browserRuntime({ ...pool, RUNNER_OS: os }, 4), serial)
})
test('metadata slots and unexpected CPU allocations cannot expand browser concurrency', () => {
  for (const cpus of [0, 1, 2, 3, 8]) assert.deepEqual(browserRuntime(pool, cpus), serial)
})
