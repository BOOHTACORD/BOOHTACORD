import { createPinia, setActivePinia } from 'pinia'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { useRealtimeStore, type RealtimeSocket } from '../realtime_store'

describe('realtime connection lifecycle', () => {
  beforeEach(() => setActivePinia(createPinia()))
  it('resyncs protected state only after a typed server event', () => {
    const socket: RealtimeSocket = { close: vi.fn(), onclose: null, onerror: null, onmessage: null, onopen: null }
    const resync = vi.fn()
    const store = useRealtimeStore()

    store.connect(resync, () => socket, 'ws://voice.example.test/api/v1/realtime')
    socket.onopen?.(new Event('open'))
    socket.onmessage?.(new MessageEvent('message', { data: JSON.stringify({ event_id: 'event-1', kind: 'connection.resync_required', occurred_at: '2026-09-17T12:00:00Z', payload: {} }) }))

    expect(store.state).toBe('CONNECTING') // A hint cannot replace server ready.
    expect(resync).toHaveBeenCalledOnce()
  })

})
