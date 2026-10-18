import { describe, expect, it } from 'vitest'

import { parseRealtimeEvent, realtimeURL, realtimeTraceURL } from './realtime_client'

describe('realtime client contract', () => {
  it('uses the same host and no credential in its websocket URL', () => {
    expect(realtimeURL({ protocol: 'https:', host: 'voice.example.test' })).toBe('wss://voice.example.test/api/v1/realtime?capabilities=role_permissions_v1,flow_tracing_v1,screen_previews_v1,screen_viewers_v1,message_social_v1')
  })

  it('carries a W3C traceparent through the browser WebSocket handshake', () => {
    const parent = '00-11111111111111111111111111111111-2222222222222222-01'
    expect(realtimeTraceURL('wss://voice.example.test/api/v1/realtime?after=cursor', parent)).toBe(`wss://voice.example.test/api/v1/realtime?after=cursor&traceparent=${parent}`)
    expect(new URL(realtimeTraceURL('wss://voice.example.test/api/v1/realtime', parent, 'vendor=state')).searchParams.get('tracestate')).toBe('vendor=state')
  })

  it('accepts only schema event kinds and typed payloads', () => {
    expect(parseRealtimeEvent({ event_id: 'event-1', kind: 'connection.resync_required', occurred_at: '2026-09-17T12:00:00Z', payload: { reason: 'replay_unavailable' } })).toMatchObject({ kind: 'connection.resync_required' })
    expect(parseRealtimeEvent({ event_id: 'event-2', kind: 'screen_preview.updated', occurred_at: '2026-10-07T10:00:00Z', payload: { lease_id: '11111111-1111-4111-8111-111111111111', generation_id: '22222222-2222-4222-8222-222222222222', revision: 1 } })).toMatchObject({ kind: 'screen_preview.updated' })
    expect(parseRealtimeEvent({ event_id: 'event-viewers', kind: 'screen_viewers.changed', occurred_at: '2026-10-18T10:00:00Z', payload: {} })).toMatchObject({ kind: 'screen_viewers.changed', payload: {} })
    expect(() => parseRealtimeEvent({ event_id: 'event-viewers-extra', kind: 'screen_viewers.changed', occurred_at: '2026-10-18T10:00:00Z', payload: { account_id: '11111111-1111-4111-8111-111111111111' } })).toThrow(/некорректное/i)
    expect(() => parseRealtimeEvent({ event_id: 'event-3', kind: 'screen_preview.updated', occurred_at: '2026-10-07T10:00:00Z', payload: { lease_id: '11111111-1111-4111-8111-222222222222', generation_id: '22222222-2222-4222-8222-222222222222', revision: 1, jpeg: 'secret' } })).toThrow(/некорректное/i)
    expect(() => parseRealtimeEvent({ kind: 'unknown' })).toThrow('некорректное')
  })

  it('accepts social hints containing only the scoped message identifiers', () => {
    const base={event_id:'event-social',occurred_at:'2026-10-09T12:00:00Z'}
    for (const kind of ['message.reactions_updated','message.pins_updated','direct_message.reactions_updated']) {
      const payload={message_id:'22222222-2222-4222-8222-222222222222',[kind.startsWith('direct')?'direct_message_id':'channel_id']:'11111111-1111-4111-8111-111111111111'}
      expect(parseRealtimeEvent({...base,kind,payload})).toMatchObject({kind,payload})
      expect(()=>parseRealtimeEvent({...base,kind,payload:{...payload,emoji:'👍'}})).toThrow(/некорректное/i)
      expect(()=>parseRealtimeEvent({...base,kind,payload:{...payload,count:7}})).toThrow(/некорректное/i)
    }
  })
})
