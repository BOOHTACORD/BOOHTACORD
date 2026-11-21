import { createPinia, setActivePinia } from 'pinia'
import { expect, it, vi } from 'vitest'
import { useRealtimeStore, type RealtimeSocket } from '../realtime_store'

it('advertises idle and sends inactivity only after server ready', () => {
  setActivePinia(createPinia())
  const send = vi.fn(), urls: string[] = []
  const socket: RealtimeSocket = { send, close: vi.fn(), onclose: null, onerror: null, onmessage: null, onopen: null }
  const store = useRealtimeStore()
  store.setConfirmedActivity(() => true, () => true)
  store.connect(vi.fn(), url => { urls.push(url); return socket }, 'ws://owned.test/api/v1/realtime')
  try {
    const capabilities = new URL(urls[0]).searchParams.get('capabilities')
    expect(capabilities).toContain('confirmed_activity_v1')
    expect(capabilities).toContain('initial_idle_v1')
    socket.onopen?.(new Event('open'))
    store.reportInactive()
    expect(send).not.toHaveBeenCalled()
    socket.onmessage?.(new MessageEvent('message', { data: JSON.stringify({
      event_id: '11111111-1111-4111-8111-111111111111', kind: 'connection.ready',
      occurred_at: '2026-11-21T00:00:00Z', payload: {},
    }) }))
    expect(store.state).toBe('CONNECTED')
    store.reportInactive(); store.reportInactive()
    expect(send).toHaveBeenCalledOnce()
    expect(JSON.parse(send.mock.calls[0][0])).toEqual({ type: 'inactive' })
  } finally { store.disconnect() }
})

it('does not send a confirmed inactivity report on a legacy connection', () => {
  setActivePinia(createPinia())
  const send = vi.fn()
  const socket: RealtimeSocket = { send, close: vi.fn(), onclose: null, onerror: null, onmessage: null, onopen: null }
  const store = useRealtimeStore()
  store.connect(vi.fn(), () => socket, 'ws://owned.test/api/v1/realtime')
  try {
    socket.onmessage?.(new MessageEvent('message', { data: JSON.stringify({
      event_id: '11111111-1111-4111-8111-111111111111', kind: 'connection.ready',
      occurred_at: '2026-11-21T00:00:00Z', payload: {},
    }) }))
    store.reportInactive()
    expect(send).not.toHaveBeenCalled()
  } finally { store.disconnect() }
})
