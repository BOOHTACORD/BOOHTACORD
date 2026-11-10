import { createPinia, setActivePinia } from 'pinia'
import { afterEach, expect, it, vi } from 'vitest'
import { useRealtimeStore, type RealtimeSocket } from './realtime_store'

afterEach(() => vi.useRealTimers())

it.each([true, false])('ignores old session check result %s after manual retry', async valid => {
  vi.useFakeTimers()
  setActivePinia(createPinia())
  let finish!: (value: boolean) => void
  const checkSession = vi.fn(() => new Promise<boolean>(resolve => { finish = resolve }))
  const sockets: RealtimeSocket[] = []
  const store = useRealtimeStore()
  const expired = vi.fn()
  store.connect(vi.fn(), () => {
    const socket: RealtimeSocket = { close: vi.fn(), onopen: null, onmessage: null, onerror: null, onclose: null }
    sockets.push(socket); return socket
  }, 'ws://example.test', { checkSession, onSessionExpired: expired, random: () => 0 })
  sockets[0].onerror?.(new Event('error'))
  store.reconnect()
  expect(sockets).toHaveLength(2)
  finish(valid)
  await vi.advanceTimersByTimeAsync(2000)
  expect(sockets).toHaveLength(2)
  expect(sockets[1].close).not.toHaveBeenCalled()
  expect(expired).not.toHaveBeenCalled()
  store.disconnect()
})
