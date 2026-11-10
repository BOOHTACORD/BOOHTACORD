import { describe, expect, it } from 'vitest'
import { parseRealtimeEvent } from './realtime_client'
import { createRealtimeDelivery } from './realtime_event_delivery'

const id = '11111111-1111-4111-8111-111111111111'
const when = '2026-11-09T00:00:00Z'
const envelope = (kind: string, payload: Record<string, unknown>) => ({ event_id: id, occurred_at: when, kind, payload })
const snapshot = () => ({ version: 1, generation: id, revision: 1, observed_at: when, channels: [
  { channel_id: id, participants: [{ account_id: id, display_name: 'Участник', screen_sharing: false, microphone_muted: true }] },
] })

describe('voice roster realtime contract', () => {
  it('accepts complete populated, empty-channel and no-channel snapshots', () => {
    const value = snapshot()
    expect(parseRealtimeEvent(envelope('voice.roster.snapshot', value)).payload).toEqual(value)
    expect(parseRealtimeEvent(envelope('voice.roster.snapshot', { ...value, channels: [{ channel_id: id, participants: [] }] })).kind).toBe('voice.roster.snapshot')
    expect(parseRealtimeEvent(envelope('voice.roster.snapshot', { ...value, channels: [] })).kind).toBe('voice.roster.snapshot')
    expect(parseRealtimeEvent(envelope('voice.roster.snapshot', { ...value, channels: [{ channel_id: id, participants: [{ ...value.channels[0].participants[0], display_name: '😀'.repeat(64) }] }] })).kind).toBe('voice.roster.snapshot')
  })

  it('rejects invalid, duplicate and extra roster fields', () => {
    const value = snapshot()
    const participant = value.channels[0].participants[0]
    for (const payload of [
      { ...value, revision: 0 }, { ...value, revision: Number.MAX_SAFE_INTEGER + 1 }, { ...value, generation: 'bad' },
      { ...value, observed_at: 'bad' }, { ...value, observed_at: '2026-02-30T00:00:00Z' }, { ...value, extra: 'private' },
      { ...value, channels: [value.channels[0], value.channels[0]] },
      { ...value, channels: [{ channel_id: id, participants: [participant, participant] }] },
      { ...value, channels: [{ channel_id: id, participants: [{ ...participant, lease_id: id }] }] },
      { ...value, channels: [{ channel_id: id, participants: [{ ...participant, microphone_muted: 'false' }] }] },
      { ...value, channels: [{ channel_id: id, participants: [{ ...participant, display_name: 'x'.repeat(65) }] }] },
    ]) expect(() => parseRealtimeEvent(envelope('voice.roster.snapshot', payload))).toThrow()
  })

  it('accepts only the fixed unavailable code and no private details', () => {
    expect(parseRealtimeEvent(envelope('voice.roster.unavailable', { version: 1, code: 'temporarily_unavailable' })).kind).toBe('voice.roster.unavailable')
    for (const payload of [{ version: 1, code: 'database timeout' }, { version: 1, code: 'temporarily_unavailable', channels: [] }, { version: 2, code: 'temporarily_unavailable' }]) {
      expect(() => parseRealtimeEvent(envelope('voice.roster.unavailable', payload))).toThrow()
    }
  })

  it('does not put roster events in the durable replay cursor', () => {
    const delivery = createRealtimeDelivery(() => {}, undefined, error => { throw error })
    delivery.accept(parseRealtimeEvent(envelope('message.created', { channel_id: id, message_id: id })))
    const ephemeral = { ...envelope('voice.roster.snapshot', snapshot()), event_id: '22222222-2222-4222-8222-222222222222' }
    delivery.accept(parseRealtimeEvent(ephemeral))
    delivery.accept(parseRealtimeEvent({ ...ephemeral, kind: 'voice.roster.unavailable', payload: { version: 1, code: 'temporarily_unavailable' } }))
    expect(delivery.cursor()).toBe(id)
  })
})
