import { createPinia, setActivePinia } from 'pinia'
import { beforeEach, describe, expect, it, vi } from 'vitest'

import { useRealtimeStore, type RealtimeSocket } from './realtime_store'

describe('realtime store', () => {
  beforeEach(() => setActivePinia(createPinia()))

  it('dispatches presence snapshots and changes without requiring chat refreshes', () => {
    const socket: RealtimeSocket = { close: vi.fn(), onclose: null, onerror: null, onmessage: null, onopen: null }
    const onEvent = vi.fn()
    const store = useRealtimeStore()
    store.connect(onEvent, () => socket, 'ws://voice.example.test/api/v1/realtime')
    const occurredAt = '2026-09-17T12:00:00Z'
    socket.onmessage?.(new MessageEvent('message', { data: JSON.stringify({ event_id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', kind: 'presence.snapshot', occurred_at: occurredAt, payload: { online_user_ids: ['11111111-1111-4111-8111-111111111111'] } }) }))
    socket.onmessage?.(new MessageEvent('message', { data: JSON.stringify({ event_id: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', kind: 'presence.changed', occurred_at: occurredAt, payload: { user_id: '11111111-1111-4111-8111-111111111111', presence: 'offline' } }) }))

    expect(onEvent).toHaveBeenCalledTimes(2)
    expect(onEvent).toHaveBeenLastCalledWith(expect.objectContaining({ kind: 'presence.changed' }))
    expect(store.state).toBe('CONNECTING')
  })

  it('rejects malformed presence IDs and unsupported status values', () => {
    for (const [kind, payload] of [
      ['presence.snapshot', { online_user_ids: ['not-a-uuid'] }],
      ['presence.changed', { user_id: '11111111-1111-4111-8111-111111111111', presence: 'away' }],
    ] as const) {
      const socket: RealtimeSocket = { close: vi.fn(), onclose: null, onerror: null, onmessage: null, onopen: null }
      const store = useRealtimeStore()
      store.connect(vi.fn(), () => socket, 'ws://voice.example.test/api/v1/realtime')
      socket.onmessage?.(new MessageEvent('message', { data: JSON.stringify({ event_id: 'cccccccc-cccc-4ccc-8ccc-cccccccccccc', kind, occurred_at: '2026-09-17T12:00:00Z', payload }) }))
      expect(store.state).toBe('ERROR')
    }
  })

  it('dispatches message-created hints only when both public IDs are present', () => {
    const socket: RealtimeSocket = { close: vi.fn(), onclose: null, onerror: null, onmessage: null, onopen: null }
    const onEvent = vi.fn()
    const store = useRealtimeStore()
    store.connect(onEvent, () => socket, 'ws://voice.example.test/api/v1/realtime')
    socket.onmessage?.(new MessageEvent('message', { data: JSON.stringify({ event_id: '33333333-3333-4333-8333-333333333333', kind: 'message.created', occurred_at: '2026-09-17T12:00:00Z', payload: { channel_id: '11111111-1111-4111-8111-111111111111', message_id: '22222222-2222-4222-8222-222222222222' } }) }))

    expect(onEvent).toHaveBeenCalledWith(expect.objectContaining({ kind: 'message.created', payload: { channel_id: '11111111-1111-4111-8111-111111111111', message_id: '22222222-2222-4222-8222-222222222222' } }))
    expect(store.state).toBe('CONNECTING')
  })

  it('dispatches message-deleted hints with only channel and message IDs', () => {
    const socket: RealtimeSocket = { close: vi.fn(), onclose: null, onerror: null, onmessage: null, onopen: null }
    const onEvent = vi.fn()
    const store = useRealtimeStore()
    store.connect(onEvent, () => socket, 'ws://voice.example.test/api/v1/realtime')
    socket.onmessage?.(new MessageEvent('message', { data: JSON.stringify({ event_id: '66666666-6666-4666-8666-666666666666', kind: 'message.deleted', occurred_at: '2026-09-17T12:00:00Z', payload: { channel_id: '11111111-1111-4111-8111-111111111111', message_id: '22222222-2222-4222-8222-222222222222' } }) }))

    expect(onEvent).toHaveBeenCalledWith(expect.objectContaining({ kind: 'message.deleted' }))
    expect(store.state).toBe('CONNECTING')
  })

  it('dispatches message-updated hints with only channel and message IDs', () => {
    const socket: RealtimeSocket = { close: vi.fn(), onclose: null, onerror: null, onmessage: null, onopen: null }
    const onEvent = vi.fn()
    const store = useRealtimeStore()
    store.connect(onEvent, () => socket, 'ws://voice.example.test/api/v1/realtime')
    socket.onmessage?.(new MessageEvent('message', { data: JSON.stringify({ event_id: '88888888-8888-4888-8888-888888888888', kind: 'message.updated', occurred_at: '2026-09-17T12:00:00Z', payload: { channel_id: '11111111-1111-4111-8111-111111111111', message_id: '22222222-2222-4222-8222-222222222222' } }) }))

    expect(onEvent).toHaveBeenCalledWith(expect.objectContaining({ kind: 'message.updated' }))
    expect(store.state).toBe('CONNECTING')
  })

  it('rejects message-updated hints missing IDs or containing message content', () => {
    for (const payload of [{ channel_id: '11111111-1111-4111-8111-111111111111' }, { channel_id: '11111111-1111-4111-8111-111111111111', message_id: '22222222-2222-4222-8222-222222222222', body: 'private' }]) {
      const socket: RealtimeSocket = { close: vi.fn(), onclose: null, onerror: null, onmessage: null, onopen: null }
      const onEvent = vi.fn()
      const store = useRealtimeStore()
      store.connect(onEvent, () => socket, 'ws://voice.example.test/api/v1/realtime')
      socket.onmessage?.(new MessageEvent('message', { data: JSON.stringify({ event_id: '99999999-9999-4999-8999-999999999999', kind: 'message.updated', occurred_at: '2026-09-17T12:00:00Z', payload }) }))
      expect(store.state).toBe('ERROR')
      expect(onEvent).not.toHaveBeenCalled()
    }
  })

  it('rejects message-deleted hints missing IDs or containing message content', () => {
    for (const payload of [{ channel_id: '11111111-1111-4111-8111-111111111111' }, { channel_id: '11111111-1111-4111-8111-111111111111', message_id: '22222222-2222-4222-8222-222222222222', body: 'private' }]) {
      const socket: RealtimeSocket = { close: vi.fn(), onclose: null, onerror: null, onmessage: null, onopen: null }
      const onEvent = vi.fn()
      const store = useRealtimeStore()
      store.connect(onEvent, () => socket, 'ws://voice.example.test/api/v1/realtime')
      socket.onmessage?.(new MessageEvent('message', { data: JSON.stringify({ event_id: '77777777-7777-4777-8777-777777777777', kind: 'message.deleted', occurred_at: '2026-09-17T12:00:00Z', payload }) }))
      expect(store.state).toBe('ERROR')
      expect(onEvent).not.toHaveBeenCalled()
    }
  })

  it('rejects message-created events without both IDs', () => {
    const socket: RealtimeSocket = { close: vi.fn(), onclose: null, onerror: null, onmessage: null, onopen: null }
    const store = useRealtimeStore()
    store.connect(vi.fn(), () => socket, 'ws://voice.example.test/api/v1/realtime')
    socket.onmessage?.(new MessageEvent('message', { data: JSON.stringify({ event_id: '44444444-4444-4444-8444-444444444444', kind: 'message.created', occurred_at: '2026-09-17T12:00:00Z', payload: { channel_id: '11111111-1111-4111-8111-111111111111' } }) }))

    expect(store.state).toBe('ERROR')
    expect(store.error).toContain('Некорректное')
  })

  it('rejects message content in a message-created payload', () => {
    const socket: RealtimeSocket = { close: vi.fn(), onclose: null, onerror: null, onmessage: null, onopen: null }
    const store = useRealtimeStore()
    store.connect(vi.fn(), () => socket, 'ws://voice.example.test/api/v1/realtime')
    socket.onmessage?.(new MessageEvent('message', { data: JSON.stringify({ event_id: '55555555-5555-4555-8555-555555555555', kind: 'message.created', occurred_at: '2026-09-17T12:00:00Z', payload: { channel_id: '11111111-1111-4111-8111-111111111111', message_id: '22222222-2222-4222-8222-222222222222', body: 'must not be broadcast' } }) }))

    expect(store.state).toBe('ERROR')
    expect(store.error).toContain('Некорректное')
  })
})
