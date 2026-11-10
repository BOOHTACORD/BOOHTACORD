import { afterEach, describe, expect, it, vi } from 'vitest'
import { createRosterSocketState } from './state'
import type { RealtimeEvent } from '../../realtime/realtime_client'

const generation = '11111111-1111-4111-8111-111111111111'
const channel = '22222222-2222-4222-8222-222222222222'
const snapshot = (revision: number, channels: unknown[] = []): RealtimeEvent => ({
  eventId: '33333333-3333-4333-8333-333333333333', kind: 'voice.roster.snapshot', occurredAt: new Date().toISOString(),
  payload: { version: 1, generation, revision, observed_at: new Date().toISOString(), channels },
})
const unavailable: RealtimeEvent = { ...snapshot(1), kind: 'voice.roster.unavailable', payload: { version: 1, code: 'temporarily_unavailable' } }

afterEach(() => vi.useRealTimers())

describe('shared realtime roster state', () => {
  it('distinguishes unknown, fresh empty and a populated snapshot', () => {
    const state = createRosterSocketState(vi.fn())
    state.start(); state.socketStart()
    expect(state.channels.value).toBeNull()
    expect(state.status.value).toBe('initial_loading')
    expect(state.accept(snapshot(1))).toBe(true)
    expect(state.status.value).toBe('fresh_empty')
    state.accept(snapshot(2, [{ channel_id: channel, participants: [] }]))
    expect(state.channels.value?.[0].channelId).toBe(channel)
    expect(state.status.value).toBe('fresh')
    state.stop()
  })

  it('retains data briefly on failure and expires it without treating unknown as empty', () => {
    vi.useFakeTimers()
    const state = createRosterSocketState(vi.fn())
    state.start(); state.socketStart(); state.accept(snapshot(1, [{ channel_id: channel, participants: [] }]))
    state.accept(unavailable)
    expect(state.status.value).toBe('stale_reconnecting')
    expect(state.channels.value).not.toBeNull()
    vi.advanceTimersByTime(10_000)
    expect(state.status.value).toBe('unavailable')
    expect(state.channels.value).toBeNull()
    state.stop()
  })

  it('ignores stale revisions and accepts a fresh initial snapshot on a new socket', () => {
    const retry = vi.fn()
    const state = createRosterSocketState(retry)
    state.start(); state.socketStart(); state.accept(snapshot(9, [{ channel_id: channel, participants: [] }]))
    state.accept(snapshot(8))
    expect(state.channels.value).toHaveLength(1)
    state.socketEnd(); state.socketStart(); state.accept(snapshot(1))
    expect(state.status.value).toBe('fresh_empty')
    state.reconnect()
    expect(retry).toHaveBeenCalledOnce()
    state.stop()
    state.accept(snapshot(2, [{ channel_id: channel, participants: [] }]))
    expect(state.channels.value).toBeNull()
  })

  it('marks a missing initial snapshot unavailable and recovers when it arrives', () => {
    vi.useFakeTimers()
    const state = createRosterSocketState(vi.fn())
    state.start(); state.socketStart()
    vi.advanceTimersByTime(10_000)
    expect(state.status.value).toBe('unavailable')
    expect(state.channels.value).toBeNull()
    state.accept(snapshot(1))
    expect(state.status.value).toBe('fresh_empty')
    state.stop()
  })
})
