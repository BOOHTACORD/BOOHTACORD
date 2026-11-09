import { afterEach, expect, it, vi } from 'vitest'
import { createRealtimeDelivery } from '../realtime_event_delivery'
import { createCoalescedDelivery } from './controller'
import type { RealtimeEvent } from '../realtime_client'

afterEach(() => vi.useRealTimers())
const event = (kind: RealtimeEvent['kind']): RealtimeEvent => ({
  eventId: 'same', kind, occurredAt: '2026-11-09T00:00:00Z', payload: {},
})

it('does not suppress a different durable kind with the same ID', async () => {
  const apply = vi.fn(), failure = vi.fn()
  const delivery = createRealtimeDelivery(apply, undefined, failure)
  delivery.accept(event('message.updated'))
  delivery.accept(event('voice.lease_revoked'))
  await vi.waitFor(() => expect(apply).toHaveBeenCalledTimes(2))
  expect(apply.mock.calls.map(([value]) => value.kind)).toEqual(['message.updated', 'voice.lease_revoked'])
  expect(failure).not.toHaveBeenCalled()
  delivery.reset()
})

it('keeps different hint kinds when coalescing a shared ID', async () => {
  vi.useFakeTimers()
  const batch = vi.fn().mockResolvedValue(undefined)
  const delivery = createCoalescedDelivery(vi.fn(), undefined, vi.fn(), batch)
  delivery.accept(event('message.created'))
  delivery.accept(event('message.updated'))
  await vi.advanceTimersByTimeAsync(30)
  expect(batch).toHaveBeenCalledOnce()
  expect(batch.mock.calls[0][0].map((value: RealtimeEvent) => value.kind)).toEqual(['message.created', 'message.updated'])
  delivery.reset()
})
