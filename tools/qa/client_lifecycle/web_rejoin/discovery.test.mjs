import assert from 'node:assert/strict'
import { test } from 'node:test'
import { discoveryGap } from './discovery.mjs'

function setup({ keys = ['ND_owned'], heartbeat = true, recover = true, apply = true } = {}) {
  let now = 0, reads = 0, removed = false, removals = 0
  const clock = { now: () => now, wait: async ms => { now += ms } }
  const port = {
    keys: async () => keys,
    read: async () => removed && (!recover || now < 300) ? Buffer.from('\n')
      : Buffer.from(heartbeat && reads++ > 0 ? 'fresh' : 'old'),
    remove: async () => { removals++; removed = apply },
  }
  return { port, clock, removals: () => removals }
}

test('waits for an actual heartbeat, verifies the gap and requires restored discovery', async () => {
  const state = setup(), restored = await discoveryGap(state.port, state.clock)
  assert.equal(state.removals(), 1)
  assert.equal(state.clock.now(), 100)
  await restored()
  assert.equal(state.clock.now(), 300)
})
for (const keys of [[], ['ND_one', 'ND_two']]) test(`refuses ${keys.length} nodes without mutation`, async () => {
  const state = setup({ keys })
  await assert.rejects(discoveryGap(state.port, state.clock), /Exactly one owned SFU/)
  assert.equal(state.removals(), 0)
})
test('fails closed without a heartbeat and leaves the registry intact', async () => {
  const state = setup({ heartbeat: false })
  await assert.rejects(discoveryGap(state.port, state.clock), /heartbeat was not observed/)
  assert.equal(state.removals(), 0)
})
test('rejects a fault that did not actually remove discovery', async () => {
  const state = setup({ apply: false })
  await assert.rejects(discoveryGap(state.port, state.clock), /fault was not applied/)
})
test('does not report recovery when the heartbeat never restores discovery', async () => {
  const state = setup({ recover: false }), restored = await discoveryGap(state.port, state.clock)
  await assert.rejects(restored(), /did not recover/)
})
