import { expect, it, vi } from 'vitest'
import { createCoalescedDelivery } from './controller'
import type { RealtimeEvent } from '../realtime_client'

const event = (kind: RealtimeEvent['kind'], id: string): RealtimeEvent =>
  ({ kind, eventId: id, occurredAt: '2026-11-12T00:00:00Z', payload: {} })

it('discards old queued snapshots and does not block a new socket on old recovery', async () => {
  let finishOld!: () => void
  const recovery = vi.fn().mockImplementationOnce(() => new Promise<void>(resolve => { finishOld = resolve }))
    .mockResolvedValue(undefined)
  const applied: string[] = []
  const delivery = createCoalescedDelivery(e => { applied.push(e.eventId) }, recovery, vi.fn(), vi.fn())
  delivery.accept(event('connection.ready', 'old-ready'))
  delivery.accept(event('voice.roster.snapshot', 'old-populated'))
  delivery.disconnected()
  delivery.accept(event('connection.ready', 'new-ready'))
  delivery.accept(event('voice.roster.snapshot', 'new-empty'))
  await vi.waitFor(() => expect(applied).toEqual(['new-empty']))
  finishOld()
  await Promise.resolve(); await Promise.resolve()
  expect(applied).toEqual(['new-empty'])
  delivery.reset()
})

it('keeps the last applied durable cursor and replays discarded pending hints', async () => {
  vi.useFakeTimers()
  try {
    const batch = vi.fn().mockResolvedValue(undefined)
    const delivery = createCoalescedDelivery(vi.fn(), undefined, vi.fn(), batch)
    delivery.accept(event('message.created', 'applied'))
    await vi.advanceTimersByTimeAsync(30)
    expect(delivery.cursor()).toBe('applied')
    delivery.accept(event('message.created', 'pending'))
    delivery.disconnected()
    expect(delivery.cursor()).toBe('applied')
    delivery.accept(event('message.created', 'pending'))
    await vi.advanceTimersByTimeAsync(30)
    expect(batch).toHaveBeenCalledTimes(2)
    expect(batch.mock.calls[1][0].map((item: RealtimeEvent) => item.eventId)).toEqual(['pending'])
    expect(delivery.cursor()).toBe('pending')
    delivery.reset()
  } finally { vi.useRealTimers() }
})
