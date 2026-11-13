import { createPinia, setActivePinia } from 'pinia'
import { afterEach, expect, it, vi } from 'vitest'
import { useRealtimeStore } from './realtime_store'
import { createGuestMaintenanceSocket } from '../maintenance/guest_socket'
import { createMaintenanceState } from '../maintenance/state'

class Socket {
  static sockets: Socket[] = []
  protocol = ''; onopen: (() => void) | null = null; onerror: (() => void) | null = null
  onclose: (() => void) | null = null; onmessage = null
  close = vi.fn()
  constructor(public url: string, public offered?: string) { Socket.sockets.push(this) }
}
afterEach(() => { Socket.sockets = []; vi.unstubAllGlobals(); vi.useRealTimers() })

it('retries the authenticated handshake without a protocol after negotiation fails', async () => {
  vi.useFakeTimers(); vi.stubGlobal('WebSocket', Socket); setActivePinia(createPinia())
  const store = useRealtimeStore()
  store.connect(() => {}, undefined, 'ws://local', { checkSession: async () => true, random: () => 0 })
  expect(Socket.sockets[0].offered).toBe('boohtacord.heartbeat.v1')
  Socket.sockets[0].onerror?.()
  await vi.advanceTimersByTimeAsync(600)
  expect(Socket.sockets[1].offered).toBeUndefined()
  store.disconnect()
})

it('retries the guest handshake without a protocol after negotiation fails', async () => {
  vi.useFakeTimers(); vi.stubGlobal('WebSocket', Socket)
  const guest = createGuestMaintenanceSocket(createMaintenanceState(), undefined, {protocol: 'https:', host: 'local'}, () => 0)
  guest.start()
  expect(Socket.sockets[0].offered).toBe('boohtacord.heartbeat.v1')
  Socket.sockets[0].onerror?.()
  await vi.advanceTimersByTimeAsync(600)
  expect(Socket.sockets[1].offered).toBeUndefined()
  guest.stop()
})
