import { describe, expect, it } from 'vitest'
import { createResponseGate } from './response_gate'

describe('held fixture responses', () => {
  it('waits for the actual request when UI pending state arrives first', async () => {
    const gate = createResponseGate()
    let released = false
    const release = gate.releaseNext().then(() => { released = true })
    await Promise.resolve()
    expect(released).toBe(false)
    const response = gate.hold()
    await Promise.all([release, response])
    expect(released).toBe(true)
  })

  it('releases only one held response at a time, in arrival order', async () => {
    const gate = createResponseGate(), completed: number[] = []
    const first = gate.hold().then(() => completed.push(1))
    const second = gate.hold().then(() => completed.push(2))
    await gate.releaseNext()
    await first
    expect(completed).toEqual([1])
    await gate.releaseNext()
    await second
    expect(completed).toEqual([1, 2])
  })

  it('waits for a new request instead of reusing the previous release callback', async () => {
    const gate = createResponseGate()
    const first = gate.hold()
    await gate.releaseNext()
    await first
    let released = false
    const secondRelease = gate.releaseNext().then(() => { released = true })
    await Promise.resolve()
    expect(released).toBe(false)
    const second = gate.hold()
    await Promise.all([secondRelease, second])
    expect(released).toBe(true)
  })
})
