import { describe, expect, it } from 'vitest'
import { parseRealtimeEvent } from './realtime_client'
import { createRealtimeDelivery } from './realtime_event_delivery'

const id = '11111111-1111-4111-8111-111111111111'
const state = { version: 1, generation: id, revision: 1, active: false }
const event = (kind: string, payload: Record<string, unknown>) => ({
  event_id: id, occurred_at: '2026-11-08T19:00:00Z', kind, payload,
})

describe('maintenance realtime contract', () => {
  for (const kind of ['maintenance.snapshot', 'maintenance.changed']) {
    it(`accepts only a typed ${kind}`, () => {
      expect(parseRealtimeEvent(event(kind, state))).toMatchObject({ kind, payload: state })
      expect(parseRealtimeEvent(event(kind, { ...state, active: true })).payload.active).toBe(true)
      for (const payload of [
        { version: 1, generation: id, revision: 1 },
        { ...state, operator: 'private' },
        { ...state, version: 2 },
        { ...state, generation: 'invalid' },
        { ...state, revision: 0 },
        { ...state, revision: 1.5 },
        { ...state, revision: Number.MAX_SAFE_INTEGER + 1 },
        { ...state, active: 'false' },
      ]) expect(() => parseRealtimeEvent(event(kind, payload))).toThrow(/некорректное/i)
    })
  }

  it('delivers snapshots without advancing the durable replay cursor', () => {
    const delivered: string[] = []
    const delivery = createRealtimeDelivery((item) => { delivered.push(item.kind) }, undefined, (error) => { throw error })
    delivery.accept(parseRealtimeEvent(event('message.created', { channel_id: id, message_id: id })))
    expect(delivery.cursor()).toBe(id)
    for (const kind of ['maintenance.snapshot', 'maintenance.changed']) {
      delivery.accept(parseRealtimeEvent(event(kind, state)))
    }
    expect(delivered).toEqual(['message.created', 'maintenance.snapshot', 'maintenance.changed'])
    expect(delivery.cursor()).toBe(id)
  })
})
