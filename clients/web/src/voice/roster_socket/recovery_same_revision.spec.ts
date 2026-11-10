import { afterEach, expect, it, vi } from 'vitest'
import type { RealtimeEvent } from '../../realtime/realtime_client'
import { createRosterSocketState } from './state'

const snapshot = (revision: number): RealtimeEvent => ({
  eventId: '33333333-3333-4333-8333-333333333333', kind: 'voice.roster.snapshot', occurredAt: new Date().toISOString(),
  payload: { version: 1, generation: '11111111-1111-4111-8111-111111111111', revision, observed_at: new Date().toISOString(), channels: [] },
})
const unavailable: RealtimeEvent = { ...snapshot(1), kind: 'voice.roster.unavailable', payload: { version: 1, code: 'temporarily_unavailable' } }
afterEach(() => vi.useRealTimers())

it('recovers an unchanged revision after unavailable without accepting an older revision', () => {
  vi.useFakeTimers()
  const state = createRosterSocketState(vi.fn())
  state.start(); state.socketStart(); state.accept(snapshot(9)); state.accept(unavailable)
  expect(state.status.value).toBe('stale_reconnecting')
  state.accept(snapshot(8))
  expect(state.status.value).toBe('stale_reconnecting')
  state.accept(snapshot(9))
  expect(state.status.value).toBe('fresh_empty')
  vi.advanceTimersByTime(10_000)
  expect(state.status.value).toBe('fresh_empty')
  state.accept(unavailable)
  vi.advanceTimersByTime(10_000)
  expect(state.status.value).toBe('unavailable')
  state.accept(snapshot(8))
  expect(state.status.value).toBe('unavailable')
  state.accept(snapshot(9))
  expect(state.status.value).toBe('fresh_empty')
  state.stop()
})
