import { createPinia, setActivePinia } from 'pinia'
import { afterEach, expect, it, vi } from 'vitest'
import { useRealtimeStore, type RealtimeSocket } from './realtime_store'

afterEach(() => vi.useRealTimers())
it.each([false, true])('retries an unready socket even when open=%s', async opened => {
  vi.useFakeTimers(); setActivePinia(createPinia())
  const sockets: RealtimeSocket[] = []
  const store = useRealtimeStore()
  store.connect(vi.fn(), () => {
    const socket: RealtimeSocket = { close: vi.fn(), onopen: null, onmessage: null, onerror: null, onclose: null }
    sockets.push(socket); return socket
  }, 'ws://example.test', { checkSession: async () => true, random: () => 0 })
  if (opened) sockets[0].onopen?.(new Event('open'))
  await vi.advanceTimersByTimeAsync(16_000)
  expect(sockets[0].close).toHaveBeenCalledOnce()
  expect(sockets).toHaveLength(2)
  store.disconnect()
})

it('does not time out after ready and does not retry after explicit disconnect', async () => {
  vi.useFakeTimers(); setActivePinia(createPinia())
  const socket: RealtimeSocket = { close: vi.fn(), onopen: null, onmessage: null, onerror: null, onclose: null }
  const factory = vi.fn(() => socket), store = useRealtimeStore()
  store.connect(vi.fn(), factory, 'ws://example.test')
  socket.onmessage?.(new MessageEvent('message', { data: JSON.stringify({ event_id: 'ready', kind: 'connection.ready',
    occurred_at: '2026-11-12T00:00:00Z', payload: {} }) }))
  await vi.advanceTimersByTimeAsync(20_000)
  expect(socket.close).not.toHaveBeenCalled()
  store.disconnect(); await vi.advanceTimersByTimeAsync(20_000)
  expect(factory).toHaveBeenCalledOnce()
})

it('retries when the session check itself never finishes', async () => {
  vi.useFakeTimers(); setActivePinia(createPinia())
  const sockets: RealtimeSocket[] = [], store = useRealtimeStore()
  let signal: AbortSignal | undefined
  store.connect(vi.fn(), () => {
    const socket: RealtimeSocket = { close: vi.fn(), onopen: null, onmessage: null, onerror: null, onclose: null }
    sockets.push(socket); return socket
  }, 'ws://example.test', { checkSession: value => { signal = value; return new Promise(() => {}) }, random: () => 0 })
  sockets[0].onerror?.(new Event('error'))
  await vi.advanceTimersByTimeAsync(20_000)
  expect(sockets).toHaveLength(2)
  expect(signal?.aborted).toBe(true)
  store.disconnect()
})

it('aborts a pending session check on explicit disconnect', async () => {
  vi.useFakeTimers(); setActivePinia(createPinia())
  let signal: AbortSignal | undefined
  const socket: RealtimeSocket = { close: vi.fn(), onopen: null, onmessage: null, onerror: null, onclose: null }
  const store = useRealtimeStore()
  store.connect(vi.fn(), () => socket, 'ws://example.test', {
    checkSession: value => { signal = value; return new Promise(() => {}) },
  })
  socket.onerror?.(new Event('error')); store.disconnect()
  expect(signal?.aborted).toBe(true)
  await vi.advanceTimersByTimeAsync(20_000)
})

it('ignores a late revoked-session result after timeout and retry', async () => {
  vi.useFakeTimers(); setActivePinia(createPinia())
  let finish!: (value: boolean) => void
  const sockets: RealtimeSocket[] = [], expired = vi.fn(), store = useRealtimeStore()
  store.connect(vi.fn(), () => {
    const socket: RealtimeSocket = { close: vi.fn(), onopen: null, onmessage: null, onerror: null, onclose: null }
    sockets.push(socket); return socket
  }, 'ws://example.test', { checkSession: () => new Promise(resolve => { finish = resolve }),
    onSessionExpired: expired, random: () => 0 })
  sockets[0].onerror?.(new Event('error'))
  await vi.advanceTimersByTimeAsync(11_000)
  expect(sockets).toHaveLength(2)
  finish(false); await vi.advanceTimersByTimeAsync(1)
  expect(expired).not.toHaveBeenCalled()
  expect(sockets[1].close).not.toHaveBeenCalled()
  store.disconnect()
})

it('ignores late open and ready callbacks from a timed-out socket', async () => {
  vi.useFakeTimers(); setActivePinia(createPinia())
  const sockets: RealtimeSocket[] = [], events = vi.fn(), store = useRealtimeStore()
  store.connect(events, () => {
    const socket: RealtimeSocket = { close: vi.fn(), onopen: null, onmessage: null, onerror: null, onclose: null }
    sockets.push(socket); return socket
  }, 'ws://example.test', { checkSession: async () => true, random: () => 0 })
  await vi.advanceTimersByTimeAsync(16_000)
  sockets[0].onopen?.(new Event('open'))
  sockets[0].onmessage?.(new MessageEvent('message', { data: JSON.stringify({ event_id: 'old', kind: 'connection.ready',
    occurred_at: '2026-11-12T00:00:00Z', payload: {} }) }))
  expect(store.state).toBe('CONNECTING')
  expect(events).not.toHaveBeenCalled()
  expect(sockets[1].close).not.toHaveBeenCalled()
  store.disconnect()
})
