import assert from 'node:assert/strict'
import { setTimeout as delay } from 'node:timers/promises'

// Remove only the owned SFU's discovery entry immediately after a heartbeat.
// Existing RTP is untouched; the next normal heartbeat must restore discovery.
export async function discoveryGap(port, clock = { now: Date.now, wait: delay }) {
  const keys = await port.keys()
  assert.equal(keys.length, 1, 'Exactly one owned SFU node required')
  const key = keys[0], initial = await port.read(key), deadline = clock.now()+5000
  assert.ok(initial.length > 1, 'Missing SFU discovery entry')
  let fresh = false
  while (clock.now() < deadline) {
    await clock.wait(100)
    const next = await port.read(key)
    if (next.length > 1 && !initial.equals(next)) { fresh = true; break }
  }
  assert.ok(fresh, 'Owned SFU heartbeat was not observed')
  await port.remove(key)
  assert.ok((await port.read(key)).length <= 1, 'Discovery fault was not applied')
  return async () => {
    const deadline = clock.now()+5000
    while (clock.now() < deadline) {
      if ((await port.read(key)).length > 1) return
      await clock.wait(100)
    }
    throw Error('Owned SFU discovery did not recover through its heartbeat')
  }
}
