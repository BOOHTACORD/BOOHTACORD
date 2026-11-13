import { createPinia, setActivePinia } from 'pinia'
import { expect, it, vi } from 'vitest'
import { createRosterSocketState } from '../voice/roster_socket/state'
import { useRealtimeStore, type RealtimeSocket } from './realtime_store'

it('keeps the new socket roster when an older recovery completes late', async () => {
  setActivePinia(createPinia())
  const store = useRealtimeStore(), roster = createRosterSocketState(() => store.reconnect())
  roster.start()
  let finishOld!: () => void
  const recovery = vi.fn().mockImplementationOnce(() => new Promise<void>(resolve => { finishOld = resolve }))
    .mockResolvedValue(undefined)
  const sockets: RealtimeSocket[] = []
  store.connect(event => { roster.accept(event) }, () => {
    const socket: RealtimeSocket = { close: vi.fn(), onopen: null, onmessage: null, onerror: null, onclose: null }
    sockets.push(socket); return socket
  }, 'ws://example.test', { onHintBatch: vi.fn(), onRecovery: recovery,
    onSocketStart: roster.socketStart, onSocketEnd: roster.socketEnd })
  const send = (socket: RealtimeSocket, kind: string, payload: object) => socket.onmessage?.(new MessageEvent('message', {
    data: JSON.stringify({ event_id: '33333333-3333-4333-8333-333333333333', kind,
      occurred_at: '2026-11-12T00:00:00Z', payload }) }))
  const snapshot = (revision: number, channels: object[]) => ({ version: 1,
    generation: '11111111-1111-4111-8111-111111111111', revision,
    observed_at: '2026-11-12T00:00:00Z', channels })
  send(sockets[0], 'connection.ready', {})
  send(sockets[0], 'voice.roster.snapshot', snapshot(7, [{ channel_id: '22222222-2222-4222-8222-222222222222', participants: [] }]))
  store.reconnect()
  send(sockets[1], 'connection.ready', {})
  send(sockets[1], 'voice.roster.snapshot', snapshot(1, []))
  await vi.waitFor(() => expect(roster.status.value).toBe('fresh_empty'))
  finishOld(); await Promise.resolve(); await Promise.resolve()
  expect(roster.channels.value).toEqual([])
  store.disconnect(); roster.stop()
})
