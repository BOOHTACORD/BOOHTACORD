import { beforeEach, expect, it, vi } from 'vitest'
import { createPinia, setActivePinia } from 'pinia'
import { useRealtimeStore, type RealtimeSocket } from '../realtime_store'

beforeEach(() => setActivePinia(createPinia()))

it('negotiates confirmed activity and sends inactive once per socket', () => {
  const send = vi.fn(), factory = vi.fn()
  const socket: RealtimeSocket = { send, close: vi.fn(), onopen: null, onclose: null, onerror: null, onmessage: null }
  factory.mockReturnValue(socket)
  const store = useRealtimeStore()
  store.setConfirmedActivity(() => true)
  store.connect(vi.fn(), factory, 'wss://example.test/api/v1/realtime?capabilities=existing')
  expect(factory.mock.calls[0]![0]).toContain('confirmed_activity_v1')
  socket.onopen?.(new Event('open'))
  store.reportInactive()
  expect(send).not.toHaveBeenCalled()
  socket.onmessage?.(new MessageEvent('message', { data: JSON.stringify({
    event_id: '11111111-1111-4111-8111-111111111111', kind: 'connection.ready',
    occurred_at: '2026-11-21T00:00:00Z', payload: {},
  }) }))
  store.reportInactive(); store.reportInactive()
  expect(send).toHaveBeenCalledTimes(1)
  expect(JSON.parse(send.mock.calls[0]![0])).toEqual({ type: 'inactive' })
  store.disconnect()
})

it('does not send inactivity to a legacy connection', () => {
  const send = vi.fn()
  const socket: RealtimeSocket = { send, close: vi.fn(), onopen: null, onclose: null, onerror: null, onmessage: null }
  const store = useRealtimeStore()
  store.connect(vi.fn(), () => socket, 'wss://example.test/api/v1/realtime')
  socket.onopen?.(new Event('open'))
  store.reportInactive()
  expect(send).not.toHaveBeenCalled()
  store.disconnect()
})

it('sends initial idle capability only for confirmed inactive observations', () => {
  const store = useRealtimeStore(), factory = vi.fn()
  const socket: RealtimeSocket = { send: vi.fn(), close: vi.fn(), onopen: null, onclose: null, onerror: null, onmessage: null }
  factory.mockReturnValue(socket)
  store.setConfirmedActivity(() => true, () => true)
  store.connect(vi.fn(), factory, 'wss://example.test/api/v1/realtime?capabilities=existing')
  const capabilities = new URL(factory.mock.calls[0]![0]).searchParams.get('capabilities')!.split(',')
  expect(capabilities).toContain('confirmed_activity_v1')
  expect(capabilities).toContain('initial_idle_v1')
  store.disconnect()
})
