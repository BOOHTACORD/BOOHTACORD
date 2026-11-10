import { afterEach, expect, it, vi } from 'vitest'
import { createRosterSocketState } from '../roster_socket/state'
import type { RealtimeEvent } from '../../realtime/realtime_client'

const snapshot = (channels: unknown[]): RealtimeEvent => ({
  eventId: 'event', kind: 'voice.roster.snapshot', occurredAt: '2026-11-09T00:00:00Z',
  payload: { version: 1, generation: '11111111-1111-4111-8111-111111111111', revision: 1, observed_at: '2026-11-09T00:00:00Z', channels },
})
afterEach(() => vi.useRealTimers())

it('expires data across manual reconnect while retaining last successful age', () => {
  vi.useFakeTimers(); vi.setSystemTime(100_000)
  const roster = createRosterSocketState(vi.fn())
  roster.start(); roster.socketStart()
  roster.accept(snapshot([{ channel_id: '22222222-2222-4222-8222-222222222222', participants: [] }]))
  roster.socketEnd(); vi.advanceTimersByTime(9000)
  roster.reconnect(); roster.socketStart(); roster.socketEnd(); vi.advanceTimersByTime(1000)
  expect(roster.channels.value).toBeNull()
  expect(roster.status.value).toBe('unavailable')
  expect(roster.lastUpdatedAt.value).toBe(100_000)
  roster.stop()
  expect(roster.lastUpdatedAt.value).toBeNull()
})

it('a successful replacement cancels the old expiry deadline', () => {
  vi.useFakeTimers()
  const roster = createRosterSocketState(vi.fn())
  roster.start(); roster.socketStart(); roster.accept(snapshot([])); roster.socketEnd()
  roster.reconnect(); roster.socketStart(); roster.accept(snapshot([]))
  vi.advanceTimersByTime(20_000)
  expect(roster.status.value).toBe('fresh_empty')
  expect(roster.channels.value).toEqual([])
  roster.stop()
})
