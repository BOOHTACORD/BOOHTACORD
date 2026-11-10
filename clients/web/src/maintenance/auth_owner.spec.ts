import { describe, expect, it } from 'vitest'
import { createMaintenanceState } from './state'
import { createAuthenticatedMaintenance } from './auth_owner'

const payload = (revision: number, active: boolean) => ({ version: 1, generation: '11111111-1111-4111-8111-111111111111', revision, active })
const event = (kind: string, revision: number, active: boolean) => ({ kind, payload: payload(revision, active) })

describe('authenticated maintenance owner', () => {
  it('consumes maintenance without consuming unrelated events', () => {
    const state = createMaintenanceState(), owner = createAuthenticatedMaintenance(state)
    owner.start()
    expect(owner.accept(event('maintenance.snapshot', 1, true))).toBe(true)
    expect(state.active.value).toBe(true)
    expect(owner.accept(event('maintenance.changed', 2, false))).toBe(true)
    expect(state.active.value).toBe(false)
    expect(owner.accept({ kind: 'message.created', payload: {} })).toBe(false)
    owner.stop()
    expect(state.known.value).toBe(false)
  })

  it('requires an initial snapshot after reconnect and rejects old owners', () => {
    const state = createMaintenanceState(), first = createAuthenticatedMaintenance(state)
    first.start(); first.accept(event('maintenance.snapshot', 2, true))
    first.stop()
    const next = createAuthenticatedMaintenance(state)
    next.start()
    expect(() => next.accept(event('maintenance.changed', 3, false))).toThrow()
    expect(next.accept(event('maintenance.snapshot', 2, true))).toBe(true)
    first.stop()
    expect(state.known.value).toBe(true)
    expect(state.active.value).toBe(true)
    next.stop()
  })
})
