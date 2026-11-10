import { createPinia, setActivePinia } from 'pinia'
import { afterEach, expect, it, vi } from 'vitest'
import { useRealtimeStore, type RealtimeSocket } from './realtime_store'

afterEach(() => vi.useRealTimers())

it('owns one lifecycle per socket attempt and ignores late failures', async () => {
  vi.useFakeTimers()
  setActivePinia(createPinia())
  const calls: string[] = []
  const sockets: RealtimeSocket[] = []
  const store = useRealtimeStore()
  store.connect(vi.fn(), () => {
    const socket: RealtimeSocket = { close: vi.fn(), onopen: null, onmessage: null, onerror: null, onclose: null }
    sockets.push(socket); return socket
  }, 'ws://example.test', { onSocketStart: () => calls.push('start'), onSocketEnd: () => calls.push('end'), checkSession: async () => true, random: () => 0 })
  expect(calls).toEqual(['start'])
  const oldClose = sockets[0].onclose!
  sockets[0].onerror?.(new Event('error'))
  await vi.advanceTimersByTimeAsync(1000)
  expect(calls).toEqual(['start', 'end', 'start'])
  oldClose({} as CloseEvent)
  expect(calls).toEqual(['start', 'end', 'start'])
  store.disconnect()
  store.disconnect()
  expect(calls).toEqual(['start', 'end', 'start', 'end'])
})

it('ends an attempt whose socket constructor throws and retries', async () => {
  vi.useFakeTimers()
  setActivePinia(createPinia())
  const calls: string[] = []
  const store = useRealtimeStore()
  store.connect(vi.fn(), () => { throw new Error('offline') }, 'ws://example.test', {
    onSocketStart: () => calls.push('start'), onSocketEnd: () => calls.push('end'), random: () => 0,
  })
  expect(calls).toEqual(['start', 'end'])
  await vi.advanceTimersByTimeAsync(500)
  expect(calls).toEqual(['start', 'end', 'start', 'end'])
  store.disconnect()
})

it('ends the previous attempt before an explicit reconnect', () => {
  setActivePinia(createPinia())
  const calls: string[] = []
  const store = useRealtimeStore()
  store.connect(vi.fn(), () => ({ close: vi.fn(), onopen: null, onmessage: null, onerror: null, onclose: null }), 'ws://example.test', {
    onSocketStart: () => calls.push('start'), onSocketEnd: () => calls.push('end'),
  })
  store.reconnect()
  expect(calls).toEqual(['start', 'end', 'start'])
  store.disconnect()
})
