import { describe, expect, it } from 'vitest'
import { createMaintenanceState } from './state'

const generationA = '11111111-1111-4111-8111-111111111111'
const generationB = '22222222-2222-4222-8222-222222222222'
const event = (kind: 'maintenance.snapshot' | 'maintenance.changed', generation: string, revision: number, active: boolean) =>
  ({ kind, payload: { version: 1, generation, revision, active } })

describe('maintenance state ownership', () => {
  it('requires snapshot and monotonically applies the current generation', () => {
    const state = createMaintenanceState()
    const owner = state.begin()
    expect(state.known.value).toBe(false)
    expect(state.accept(owner, event('maintenance.changed', generationA, 1, true))).toBe(false)
    expect(state.accept(owner, event('maintenance.snapshot', generationA, 2, true))).toBe(true)
    expect(state.active.value).toBe(true)
    expect(state.accept(owner, event('maintenance.changed', generationA, 2, false))).toBe(false)
    expect(state.accept(owner, event('maintenance.changed', generationB, 3, false))).toBe(false)
    expect(state.accept(owner, event('maintenance.changed', generationA, 3, false))).toBe(true)
    expect(state.active.value).toBe(false)
  })

  it('rejects late callbacks and accepts a new server generation on reconnect', () => {
    const state = createMaintenanceState()
    const old = state.begin()
    expect(state.accept(old, event('maintenance.snapshot', generationA, 8, true))).toBe(true)
    const current = state.begin()
    expect(state.known.value).toBe(false)
    expect(state.active.value).toBe(true)
    expect(state.accept(old, event('maintenance.changed', generationA, 9, false))).toBe(false)
    expect(state.accept(current, event('maintenance.snapshot', generationB, 1, false))).toBe(true)
    expect(state.accept(old, event('maintenance.snapshot', generationA, 10, true))).toBe(false)
    state.disconnected(old)
    expect(state.known.value).toBe(true)
    state.disconnected(current)
    expect(state.known.value).toBe(false)
    expect(state.active.value).toBe(false)
  })

  it('rejects malformed payloads and stale snapshots on one connection', () => {
    const state = createMaintenanceState()
    const owner = state.begin()
    expect(state.accept(owner, { kind: 'maintenance.snapshot', payload: { active: false } })).toBe(false)
    expect(state.accept(owner, event('maintenance.snapshot', generationA, 2, true))).toBe(true)
    expect(state.accept(owner, event('maintenance.snapshot', generationA, 1, false))).toBe(false)
    expect(state.accept(owner, event('maintenance.snapshot', generationB, 3, false))).toBe(false)
    expect(state.active.value).toBe(true)
  })

  it('does not accept contradictory or older revisions after reconnect', () => {
    const state = createMaintenanceState()
    const old = state.begin()
    state.accept(old, event('maintenance.snapshot', generationA, 3, true))
    const current = state.begin()
    expect(state.accept(current, event('maintenance.snapshot', generationA, 2, false))).toBe(false)
    expect(state.accept(current, event('maintenance.snapshot', generationA, 3, false))).toBe(false)
    expect(state.accept(current, event('maintenance.snapshot', generationA, 3, true))).toBe(true)
    expect(state.accept(current, event('maintenance.changed', generationA, 4, false))).toBe(true)
  })
})
