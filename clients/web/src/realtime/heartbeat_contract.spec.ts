import { expect, it } from 'vitest'
import { parseRealtimeEvent } from './realtime_client'

it('accepts only a complete, empty heartbeat envelope', () => {
  const valid = { event_id: '11111111-1111-4111-8111-111111111111', kind: 'connection.heartbeat',
    occurred_at: '2026-11-13T00:00:00Z', payload: {} }
  expect(parseRealtimeEvent(valid).kind).toBe('connection.heartbeat')
  for (const bad of [
    { ...valid, event_id: 'not-a-uuid' },
    { ...valid, payload: { account_id: 'private' } },
    { ...valid, telemetry: {} },
    { ...valid, extra: true },
  ]) expect(() => parseRealtimeEvent(bad)).toThrow()
})
