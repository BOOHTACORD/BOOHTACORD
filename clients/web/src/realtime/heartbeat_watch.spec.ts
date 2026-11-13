import { createPinia, setActivePinia } from 'pinia'
import { afterEach, expect, it, vi } from 'vitest'
import { useRealtimeStore } from './realtime_store'
import type { RealtimeSocket } from './realtime_connection_types'
import { createGuestMaintenanceSocket } from '../maintenance/guest_socket'
import { createMaintenanceState } from '../maintenance/state'

class Socket {
  protocol = 'boohtacord.heartbeat.v1'
  onclose: RealtimeSocket['onclose'] = null
  onerror: RealtimeSocket['onerror'] = null
  onmessage: RealtimeSocket['onmessage'] = null
  onopen: RealtimeSocket['onopen'] = null
  close = vi.fn()
  emit(kind: string, payload: Record<string, unknown>) {
    this.onmessage?.({ data: JSON.stringify({ event_id: '11111111-1111-4111-8111-111111111111',
      occurred_at: '2026-11-13T00:00:00Z', kind, payload }) } as MessageEvent<string>)
  }
}
afterEach(() => { vi.unstubAllGlobals(); vi.useRealTimers() })

it('reconnects an authenticated silent socket and does not deliver heartbeats', async () => {
  vi.useFakeTimers(); setActivePinia(createPinia())
  const sockets: Socket[] = [], delivered = vi.fn(), ended = vi.fn(), store = useRealtimeStore()
  store.connect(delivered, () => { const socket = new Socket(); sockets.push(socket); return socket }, 'ws://local',
    { checkSession: async () => true, onSocketEnd: ended, random: () => 0 })
  sockets[0].onopen?.(new Event('open')); sockets[0].emit('connection.ready', {})
  await vi.advanceTimersByTimeAsync(44_000)
  sockets[0].emit('connection.heartbeat', {})
  expect(store.state).toBe('CONNECTED')
  expect(delivered).not.toHaveBeenCalled()
  await vi.advanceTimersByTimeAsync(44_000)
  expect(sockets[0].close).not.toHaveBeenCalled()
  await vi.advanceTimersByTimeAsync(2_000)
  expect(sockets[0].close).toHaveBeenCalledOnce()
  expect(ended).toHaveBeenCalledOnce()
  expect(sockets.length).toBeGreaterThan(1)
  store.disconnect()
})

it('marks guest maintenance unknown and retries when heartbeats stop', async () => {
  vi.useFakeTimers()
  const state = createMaintenanceState(), sockets: Socket[] = []
  const guest = createGuestMaintenanceSocket(state, () => { const socket = new Socket(); sockets.push(socket); return socket },
    { protocol: 'https:', host: 'voice.example.test' }, () => 0)
  guest.start(); sockets[0].emit('connection.ready', {})
  sockets[0].emit('maintenance.snapshot', { version: 1, generation: '11111111-1111-4111-8111-111111111111', revision: 1, active: false })
  expect(state.known.value).toBe(true)
  await vi.advanceTimersByTimeAsync(44_000)
  sockets[0].emit('connection.heartbeat', {})
  expect(state.known.value).toBe(true)
  await vi.advanceTimersByTimeAsync(46_000)
  expect(sockets[0].close).toHaveBeenCalledOnce()
  expect(state.known.value).toBe(false)
  expect(sockets.length).toBeGreaterThan(1)
  guest.stop()
})

it('rechecks elapsed silence immediately when a hidden page becomes visible', async () => {
  vi.useFakeTimers(); setActivePinia(createPinia()); vi.setSystemTime(new Date('2026-11-13T00:00:00Z'))
  const sockets: Socket[] = [], store = useRealtimeStore()
  const visibleDocument = Object.assign(new EventTarget(), { visibilityState: 'visible' })
  vi.stubGlobal('document', visibleDocument)
  store.connect(() => {}, () => { const socket = new Socket(); sockets.push(socket); return socket }, 'ws://local',
    { checkSession: async () => true, random: () => 0 })
  sockets[0].emit('connection.ready', {})
  vi.setSystemTime(new Date('2026-11-13T00:00:46Z'))
  document.dispatchEvent(new Event('visibilitychange'))
  expect(sockets[0].close).toHaveBeenCalledOnce()
  store.disconnect()
})

it('reconnects the application socket after the browser comes online', () => {
  vi.useFakeTimers(); setActivePinia(createPinia())
  const onlineWindow = Object.assign(new EventTarget(), { location: { host: 'local' } })
  vi.stubGlobal('window', onlineWindow)
  const socket = new Socket(), store = useRealtimeStore()
  store.connect(() => {}, () => socket, 'ws://local', { checkSession: async () => true })
  socket.emit('connection.ready', {})
  window.dispatchEvent(new Event('online'))
  expect(socket.close).toHaveBeenCalledOnce()
  store.disconnect()
})

it('rejects a heartbeat before the ready frame', () => {
  vi.useFakeTimers(); setActivePinia(createPinia())
  const socket = new Socket(), store = useRealtimeStore()
  store.connect(() => {}, () => socket, 'ws://local', { checkSession: async () => true })
  socket.emit('connection.heartbeat', {})
  expect(socket.close).toHaveBeenCalledOnce()
  store.disconnect()
})

it('does not arm a heartbeat deadline on an unnegotiated legacy socket', async () => {
  vi.useFakeTimers(); setActivePinia(createPinia())
  const socket = new Socket(), store = useRealtimeStore()
  socket.protocol = ''
  store.connect(() => {}, () => socket, 'ws://local')
  socket.emit('connection.ready', {})
  await vi.advanceTimersByTimeAsync(60_000)
  expect(socket.close).not.toHaveBeenCalled()
  store.disconnect()
})
