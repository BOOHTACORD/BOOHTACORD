import { createPinia, setActivePinia } from 'pinia'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { realtimeURL } from './realtime_client'
import { reconnectDelay } from './reconnect_policy'
import { useRealtimeStore, type RealtimeSocket } from './realtime_store'

const channelID = '11111111-1111-4111-8111-111111111111'
const messageID = '22222222-2222-4222-8222-222222222222'
const eventID = '33333333-3333-4333-8333-333333333333'
const timestamp = '2026-09-25T00:00:00Z'

function fakeSocket(): RealtimeSocket {
  return { close: vi.fn(), onclose: null, onerror: null, onmessage: null, onopen: null }
}

function send(socket: RealtimeSocket, kind: string, id = eventID, payload: Record<string, unknown> = {}): void {
  socket.onmessage?.(new MessageEvent('message', { data: JSON.stringify({ event_id: id, kind, occurred_at: timestamp, payload }) }))
}

describe('realtime recovery', () => {
  beforeEach(() => { setActivePinia(createPinia()); vi.useFakeTimers() })
  afterEach(() => vi.useRealTimers())

  it('uses an encoded durable cursor on reconnect and deduplicates replay', async () => {
    const sockets = [fakeSocket(), fakeSocket()]
    const urls: string[] = []
    const onEvent = vi.fn()
    const store = useRealtimeStore()
    store.connect(onEvent, (url) => { urls.push(url); return sockets[urls.length - 1] }, 'ws://voice.test/api/v1/realtime', { checkSession: async () => true, random: () => 0.5 })
    send(sockets[0], 'message.created', eventID, { channel_id: channelID, message_id: messageID })
    sockets[0].onclose?.({ code: 1006 } as CloseEvent)
    await vi.advanceTimersByTimeAsync(500)
    expect(urls).toEqual(['ws://voice.test/api/v1/realtime', `ws://voice.test/api/v1/realtime?after=${eventID}`])
    send(sockets[1], 'message.created', eventID, { channel_id: channelID, message_id: messageID })
    expect(onEvent).toHaveBeenCalledTimes(1)
  })

  it('waits for protected REST recovery before applying later durable hints', async () => {
    const socket = fakeSocket()
    let finishRecovery!: () => void
    const recovery = new Promise<void>((resolve) => { finishRecovery = resolve })
    const onEvent = vi.fn()
    const onRecovery = vi.fn(() => recovery)
    const store = useRealtimeStore()
    store.connect(onEvent, () => socket, 'ws://voice.test/api/v1/realtime', { onRecovery })
    send(socket, 'connection.ready')
    send(socket, 'message.created', eventID, { channel_id: channelID, message_id: messageID })
    expect(onRecovery).toHaveBeenCalledOnce()
    expect(onEvent).not.toHaveBeenCalled()
    finishRecovery()
    await vi.waitFor(() => expect(onEvent).toHaveBeenCalledOnce())
  })

  it('clears an invalid cursor and performs full resync before reconnect', async () => {
    const sockets = [fakeSocket(), fakeSocket()]
    const urls: string[] = []
    const onEvent = vi.fn()
    const store = useRealtimeStore()
    store.connect(onEvent, (url) => { urls.push(url); return sockets[urls.length - 1] }, 'ws://voice.test/api/v1/realtime', { checkSession: async () => true, random: () => 0.5 })
    send(sockets[0], 'message.created', eventID, { channel_id: channelID, message_id: messageID })
    send(sockets[0], 'connection.resync_required', '44444444-4444-4444-8444-444444444444', { reason: 'cursor_expired' })
    sockets[0].onclose?.({ code: 1006 } as CloseEvent)
    await vi.advanceTimersByTimeAsync(500)
    expect(onEvent).toHaveBeenCalledWith(expect.objectContaining({ kind: 'connection.resync_required' }))
    expect(urls[1]).toBe('ws://voice.test/api/v1/realtime')
  })

  it('cancels retry and clears account-bound cursor on dispose', async () => {
    const sockets = [fakeSocket(), fakeSocket()]
    const urls: string[] = []
    const store = useRealtimeStore()
    store.connect(vi.fn(), (url) => { urls.push(url); return sockets[urls.length - 1] }, 'ws://voice.test/api/v1/realtime', { checkSession: async () => true, random: () => 0.5 })
    send(sockets[0], 'message.created', eventID, { channel_id: channelID, message_id: messageID })
    sockets[0].onclose?.({ code: 1006 } as CloseEvent)
    store.disconnect()
    await vi.advanceTimersByTimeAsync(30_000)
    expect(urls).toHaveLength(1)
    store.connect(vi.fn(), (url) => { urls.push(url); return sockets[1] }, 'ws://voice.test/api/v1/realtime')
    expect(urls[1]).toBe('ws://voice.test/api/v1/realtime')
  })

  it('reports a revoked session instead of retrying forever', async () => {
    const socket = fakeSocket()
    const expired = vi.fn()
    const store = useRealtimeStore()
    store.connect(vi.fn(), () => socket, 'ws://voice.test/api/v1/realtime', { checkSession: async () => false, onSessionExpired: expired })
    socket.onclose?.({ code: 1008 } as CloseEvent)
    await Promise.resolve()
    await vi.advanceTimersByTimeAsync(30_000)
    expect(expired).toHaveBeenCalledOnce()
    expect(store.state).toBe('DISCONNECTED')
  })

  it('bounds exponential retry and treats an unavailable session check as transient', async () => {
    expect(reconnectDelay(0, () => 0)).toBe(400)
    expect(reconnectDelay(0, () => 1)).toBe(600)
    expect(reconnectDelay(100, () => 1)).toBe(15_000)
    const sockets = [fakeSocket(), fakeSocket()]
    const factory = vi.fn(() => sockets[factory.mock.calls.length - 1])
    const store = useRealtimeStore()
    store.connect(vi.fn(), factory, 'ws://voice.test/api/v1/realtime', { checkSession: async () => { throw new Error('network') }, random: () => 0.5 })
    sockets[0].onclose?.({ code: 1006 } as CloseEvent)
    await vi.advanceTimersByTimeAsync(500)
    expect(factory).toHaveBeenCalledTimes(2)
  })

  it('keeps control and presence IDs out of the durable cursor', async () => {
    expect(realtimeURL({ protocol: 'https:', host: 'voice.test' }, eventID)).toBe(`wss://voice.test/api/v1/realtime?capabilities=role_permissions_v1,flow_tracing_v1,screen_previews_v1,screen_viewers_v1,message_social_v1,notifications_v1&after=${eventID}`)
    const sockets = [fakeSocket(), fakeSocket()]
    const urls: string[] = []
    const store = useRealtimeStore()
    store.connect(vi.fn(), (url) => { urls.push(url); return sockets[urls.length - 1] }, 'ws://voice.test/api/v1/realtime', { checkSession: async () => true, random: () => 0.5 })
    send(sockets[0], 'connection.ready', eventID)
    send(sockets[0], 'presence.snapshot', eventID, { online_user_ids: [] })
    sockets[0].onclose?.({ code: 1006 } as CloseEvent)
    await vi.advanceTimersByTimeAsync(500)
    expect(urls[1]).toBe('ws://voice.test/api/v1/realtime')
  })
})
