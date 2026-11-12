import { afterEach, describe, expect, it, vi } from 'vitest'
import type { RealtimeSocket } from '../realtime/realtime_connection_types'
import { createMaintenanceState } from './state'
import { createGuestMaintenanceSocket } from './guest_socket'

class Socket {
  onclose: RealtimeSocket['onclose'] = null
  onerror: RealtimeSocket['onerror'] = null
  onmessage: RealtimeSocket['onmessage'] = null
  onopen: RealtimeSocket['onopen'] = null
  close = vi.fn()
  emit(kind: string, payload: Record<string, unknown>) {
    this.onmessage?.({ data: JSON.stringify({ event_id: '11111111-1111-4111-8111-111111111111', occurred_at: '2026-11-09T00:00:00Z', kind, payload }) } as MessageEvent<string>)
  }
}
const payload = (revision: number, active: boolean) => ({ version: 1, generation: '11111111-1111-4111-8111-111111111111', revision, active })
afterEach(() => vi.useRealTimers())

describe('guest maintenance WebSocket', () => {
  it('opens one public socket and accepts only its authoritative state', () => {
    const state = createMaintenanceState(), socket = new Socket(), factory = vi.fn(() => socket)
    const guest = createGuestMaintenanceSocket(state, factory, { protocol: 'https:', host: 'voice.example.test' }, () => 0)
    guest.start(); guest.start()
    expect(factory).toHaveBeenCalledOnce()
    expect(factory).toHaveBeenCalledWith('wss://voice.example.test/api/v1/public/realtime')
    socket.emit('connection.ready', {})
    socket.emit('maintenance.snapshot', payload(1, true))
    expect(state.active.value).toBe(true)
    expect(state.known.value).toBe(true)
    socket.emit('maintenance.changed', payload(2, false))
    expect(state.active.value).toBe(false)
    guest.stop()
    expect(socket.close).toHaveBeenCalledOnce()
    expect(state.known.value).toBe(false)
  })

  it('retries a stalled initial snapshot and ignores a previous socket', async () => {
    vi.useFakeTimers()
    const state = createMaintenanceState(), sockets: Socket[] = []
    const guest = createGuestMaintenanceSocket(state, () => { const socket = new Socket(); sockets.push(socket); return socket }, { protocol: 'http:', host: 'localhost' }, () => 0)
    guest.start()
    const oldCallback = sockets[0].onmessage!
    await vi.advanceTimersByTimeAsync(5000)
    expect(sockets.length).toBeGreaterThan(1)
    oldCallback({ data: JSON.stringify({ event_id: 'old', occurred_at: '2026-11-09T00:00:00Z', kind: 'maintenance.snapshot', payload: payload(1, true) }) } as MessageEvent<string>)
    expect(state.known.value).toBe(false)
    sockets[1].emit('connection.ready', {})
    sockets[1].emit('maintenance.snapshot', payload(1, false))
    expect(state.known.value).toBe(true)
    guest.stop()
    const count = sockets.length
    await vi.advanceTimersByTimeAsync(10000)
    expect(sockets).toHaveLength(count)
  })

  it('rejects protected or malformed frames and retries', async () => {
    vi.useFakeTimers()
    const state = createMaintenanceState(), sockets: Socket[] = []
    const guest = createGuestMaintenanceSocket(state, () => { const socket = new Socket(); sockets.push(socket); return socket }, { protocol: 'http:', host: 'localhost' }, () => 0)
    guest.start()
    sockets[0].emit('session.state_changed', {})
    expect(sockets[0].close).toHaveBeenCalledOnce()
    await vi.advanceTimersByTimeAsync(1000)
    sockets[1].onmessage?.({ data: '{bad' } as MessageEvent<string>)
    expect(sockets[1].close).toHaveBeenCalledOnce()
    guest.stop()
  })
})
