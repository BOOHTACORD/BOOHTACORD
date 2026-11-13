import { createPinia, setActivePinia } from 'pinia'
import { afterEach, expect, it, vi } from 'vitest'
import { useRealtimeStore } from './realtime_store'
import type { RealtimeSocket } from './realtime_connection_types'

it.each([[false, false], [false, true], [true, false], [true, true]])('malformed frame clears replay cursor (batching=%s, manual=%s)', async (batching, manual) => {
  vi.useFakeTimers(); setActivePinia(createPinia())
  const sockets: RealtimeSocket[] = [], urls: string[] = []
  const factory = (url: string) => {
    urls.push(url)
    const socket: RealtimeSocket = { onopen: null, onclose: null, onerror: null, onmessage: null, close: vi.fn() }
    sockets.push(socket); return socket
  }
  const store = useRealtimeStore()
  store.connect(() => {}, factory, 'ws://local/realtime', {
    checkSession: async () => true, random: () => 0,
    ...(batching ? { onHintBatch: async () => {} } : {}),
  })
  sockets[0].onmessage?.({ data: JSON.stringify({ event_id: 'old-cursor', kind: 'message.created',
    occurred_at: '2026-11-13T00:00:00Z', payload: { channel_id: '11111111-1111-4111-8111-111111111111',
      message_id: '22222222-2222-4222-8222-222222222222' } }) } as MessageEvent<string>)
  await vi.advanceTimersByTimeAsync(100)
  sockets[0].onmessage?.({ data: '{' } as MessageEvent<string>)
  if (manual) store.reconnect()
  else await vi.advanceTimersByTimeAsync(1000)
  expect(urls).toHaveLength(2)
  expect(urls[1]).not.toContain('after=')
  store.disconnect()
})

afterEach(() => vi.useRealTimers())
