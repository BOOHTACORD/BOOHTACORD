import { afterEach, expect, it, vi } from 'vitest'
import { createCoalescedDelivery } from './controller'
import type { RealtimeEvent } from '../realtime_client'

afterEach(() => vi.useRealTimers())

function hint(id: string): RealtimeEvent {
  return { eventId: id, kind: 'message.created', occurredAt: '2026-11-09T00:00:00Z',
    payload: { channel_id: 'room', message_id: id } }
}

it('bounds hints before the batch timer fires and demands recovery', () => {
  vi.useFakeTimers()
  const failure = vi.fn()
  const delivery = createCoalescedDelivery(vi.fn(), undefined, failure, vi.fn())
  for (let i = 0; i < 257; i++) delivery.accept(hint(String(i)))
  expect(failure).toHaveBeenCalledOnce()
  expect(delivery.cursor()).toBeNull()
  delivery.reset()
})

it('accepts the full limit and acknowledges it only after the batch succeeds', async () => {
  vi.useFakeTimers()
  const failure = vi.fn(), batch = vi.fn().mockResolvedValue(undefined)
  const delivery = createCoalescedDelivery(vi.fn(), undefined, failure, batch)
  for (let i = 0; i < 256; i++) delivery.accept(hint(String(i)))
  expect(failure).not.toHaveBeenCalled()
  expect(delivery.cursor()).toBeNull()
  await vi.advanceTimersByTimeAsync(30)
  expect(batch.mock.calls[0][0]).toHaveLength(256)
  expect(delivery.cursor()).toBe('255')
  delivery.reset()
})

it('bounds queued and in-flight hints while still delivering an immediate revoke', async () => {
  vi.useFakeTimers()
  let finish!: () => void
  const onEvent = vi.fn(), failure = vi.fn()
  const batch = vi.fn(() => new Promise<void>(resolve => { finish = resolve }))
  const delivery = createCoalescedDelivery(onEvent, undefined, failure, batch)
  for (let i = 0; i < 128; i++) delivery.accept(hint(`first-${i}`))
  await vi.advanceTimersByTimeAsync(30)
  const revoke = { ...hint('revoke'), kind: 'voice.lease_revoked' as const,
    payload: { lease_id: 'lease', reason: 'session_revoked' } }
  delivery.accept(revoke)
  expect(onEvent).toHaveBeenCalledWith(revoke)
  for (let i = 0; i < 129; i++) delivery.accept(hint(`second-${i}`))
  expect(failure).toHaveBeenCalledOnce()
  finish()
  await Promise.resolve(); await Promise.resolve()
  expect(delivery.cursor()).toBeNull()
  delivery.reset()
})

it('does not let an old batch reduce the limit after recovery', async () => {
  vi.useFakeTimers()
  let finish!: () => void
  const failure = vi.fn()
  const delivery = createCoalescedDelivery(vi.fn(), undefined, failure,
    () => new Promise<void>(resolve => { finish = resolve }))
  for (let i = 0; i < 128; i++) delivery.accept(hint(`old-${i}`))
  await vi.advanceTimersByTimeAsync(30)
  for (let i = 0; i < 129; i++) delivery.accept(hint(`overflow-${i}`))
  expect(failure).toHaveBeenCalledTimes(1)
  finish(); await Promise.resolve(); await Promise.resolve()
  for (let i = 0; i < 257; i++) delivery.accept(hint(`new-${i}`))
  expect(failure).toHaveBeenCalledTimes(2)
  expect(delivery.cursor()).toBeNull()
  delivery.reset()
})
