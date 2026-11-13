import { createPinia, setActivePinia } from 'pinia'
import { afterEach, expect, it, vi } from 'vitest'
import { useRealtimeStore } from './realtime_store'
import type { RealtimeSocket } from './realtime_connection_types'

it.each(['{"kind":', new Uint8Array([1, 2])])('closes and retries after malformed or binary frame', data => {
  vi.useFakeTimers(); setActivePinia(createPinia())
  const socket: RealtimeSocket = { onopen: null, onclose: null, onerror: null, onmessage: null, close: vi.fn() }
  const store = useRealtimeStore()
  store.connect(() => {}, () => socket, 'ws://local', { checkSession: async () => true, random: () => 0 })
  socket.onmessage?.({ data } as MessageEvent<string>)
  expect(socket.close).toHaveBeenCalledOnce()
  expect(store.state).toBe('DISCONNECTED')
  store.disconnect()
})

afterEach(() => vi.useRealTimers())
