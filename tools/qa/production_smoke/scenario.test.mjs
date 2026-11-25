import assert from 'node:assert/strict'
import { test } from 'node:test'
import { runScenario } from './scenario.mjs'
import { publicRevision } from './public.mjs'

const sha = 'a'.repeat(40)

function fixture(overrides = {}) {
  const calls = []
  const adapter = {
    revision: async () => sha,
    login: async () => calls.push('login'),
    selectEmptyRoom: async () => calls.push('room'),
    connect: async () => calls.push('connect'),
    publish: async () => calls.push('publish'),
    disconnect: async () => calls.push('disconnect'),
    logout: async () => calls.push('logout'),
    close: async () => calls.push('close'),
    ...overrides,
  }
  return { adapter, calls }
}

test('checks exact source before and after a real listener session', async () => {
  const { adapter, calls } = fixture()
  const stages = []
  await runScenario(adapter, sha, stage => stages.push(stage))
  assert.deepEqual(calls, ['login', 'room', 'connect', 'publish', 'disconnect', 'logout', 'close'])
  assert.deepEqual(stages, ['source_before', 'login', 'room', 'connect', 'publish', 'disconnect', 'logout', 'source_after'])
})

test('refuses to connect when the deployed revision differs', async () => {
  const { adapter, calls } = fixture({ revision: async () => 'b'.repeat(40) })
  await assert.rejects(runScenario(adapter, sha))
  assert.deepEqual(calls, ['close'])
})

test('fails if the revision changes while checking', async () => {
  let calls = 0
  const { adapter } = fixture({ revision: async () => ++calls === 1 ? sha : 'b'.repeat(40) })
  await assert.rejects(runScenario(adapter, sha))
})

test('fails on peer connection or disconnect failure and always closes the browser', async () => {
  for (const method of ['connect', 'publish', 'disconnect', 'logout']) {
    const { adapter, calls } = fixture({ [method]: async () => { throw Error('failure') } })
    await assert.rejects(runScenario(adapter, sha))
    assert.equal(calls.at(-1), 'close')
  }
})

test('rejects malformed expected revisions', async () => {
  const { adapter } = fixture()
  await assert.rejects(runScenario(adapter, 'master'))
})

test('health and exact-source receipt must both be successful', async () => {
  const request = async url => ({ ok: true, url, json: async () => url.endsWith('/health') ? { status: 'ok' } : { source_revision: sha } })
  assert.equal(await publicRevision(request), sha)
  await assert.rejects(publicRevision(async url => ({ ok: false, url })))
  await assert.rejects(publicRevision(async url => ({ ok: true, url: 'https://other.example', json: async () => ({ status: 'ok' }) })))
  await assert.rejects(publicRevision(async url => ({ ok: true, url, json: async () => ({ status: 'degraded' }) })))
})
