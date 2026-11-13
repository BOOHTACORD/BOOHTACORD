import { createPinia, setActivePinia } from 'pinia'
import { afterEach, expect, it, vi } from 'vitest'
import { parseRealtimeEvent } from './realtime_client'
import { useRealtimeStore } from './realtime_store'
import type { RealtimeSocket } from './realtime_connection_types'
import { createGuestMaintenanceSocket } from '../maintenance/guest_socket'
import { createMaintenanceState } from '../maintenance/state'

const id = '11111111-1111-4111-8111-111111111111'
const state = { version: 1, generation: id, revision: 1, active: false }
const good = { event_id: id, kind: 'maintenance.snapshot', occurred_at: '2026-11-13T00:00:00Z', payload: state }
const telemetry = { reference: 'local', trace_id: '1'.repeat(32), span_id: '2'.repeat(16) }

it('strictly validates new event envelopes and optional telemetry', () => {
  expect(parseRealtimeEvent(good).kind).toBe(good.kind)
  expect(parseRealtimeEvent({ ...good, telemetry }).telemetry?.reference).toBe('local')
  for (const invalid of [
    { ...good, event_id: 'not-a-uuid' }, { ...good, occurred_at: '2026-02-30T00:00:00Z' },
    { ...good, occurred_at: undefined }, { ...good, unexpected: 'private' },
    { ...good, telemetry: { ...telemetry, extra: 'private' } },
    { ...good, telemetry: { ...telemetry, trace_id: '0'.repeat(32) } },
    { ...good, telemetry: null },
  ]) expect(() => parseRealtimeEvent(invalid)).toThrow()
})

it('closes and retries an authenticated socket after malformed input', async () => {
  vi.useFakeTimers(); setActivePinia(createPinia())
  const socket: RealtimeSocket = { onopen: null, onclose: null, onerror: null, onmessage: null, close: vi.fn() }
  const store = useRealtimeStore()
  store.connect(() => {}, () => socket, 'ws://local', { checkSession: async () => true, random: () => 0 })
  socket.onmessage?.({ data: JSON.stringify({ ...good, unexpected: true }) } as MessageEvent<string>)
  expect(socket.close).toHaveBeenCalledOnce()
  expect(store.state).toBe('DISCONNECTED')
  store.disconnect()
})

it('returns guest maintenance to unknown after an invalid envelope', () => {
  vi.useFakeTimers()
  const socket: RealtimeSocket = { onopen: null, onclose: null, onerror: null, onmessage: null, close: vi.fn() }
  const state = createMaintenanceState()
  const guest = createGuestMaintenanceSocket(state, () => socket, { protocol: 'https:', host: 'local' })
  guest.start()
  socket.onmessage?.({ data: JSON.stringify({ ...good, kind: 'connection.ready', payload: {} }) } as MessageEvent<string>)
  socket.onmessage?.({ data: JSON.stringify(good) } as MessageEvent<string>)
  expect(state.known.value).toBe(true)
  socket.onmessage?.({ data: JSON.stringify({ ...good, kind: 'maintenance.changed', unexpected: true }) } as MessageEvent<string>)
  expect(state.known.value).toBe(false)
  expect(socket.close).toHaveBeenCalledOnce()
  guest.stop()
})
afterEach(() => vi.useRealTimers())
