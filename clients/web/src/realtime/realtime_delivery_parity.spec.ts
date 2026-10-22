import { describe, it, expect, vi } from 'vitest'
import { createRealtimeDelivery } from './realtime_event_delivery'
import type { RealtimeEvent } from './realtime_client'
const event = (id: string): RealtimeEvent => ({ eventId: id, kind: 'message.updated', occurredAt: '2026-10-22T00:00:00Z', payload: {} })
describe('PAR-01 delivery regression', () => {
  it('does not acknowledge unfinished work, deduplicates and keeps the last applied cursor', async () => {
    let finish!: () => void
    const apply = vi.fn((e: RealtimeEvent) => e.eventId === 'one' ? new Promise<void>(resolve => { finish = resolve }) : undefined)
    const delivery = createRealtimeDelivery(apply, undefined, vi.fn())
    delivery.accept(event('one')); delivery.accept(event('two')); delivery.accept(event('two'))
    expect(delivery.cursor()).toBeNull(); expect(apply).toHaveBeenCalledTimes(1)
    finish(); await Promise.resolve(); await Promise.resolve()
    expect(delivery.cursor()).toBe('two'); expect(apply).toHaveBeenCalledTimes(2)
  })
  it('bounds backlog and invalidates late acknowledgement after overflow', async () => {
    let finish!: () => void
    const failed = vi.fn()
    const delivery = createRealtimeDelivery(() => new Promise<void>(resolve => { finish = resolve }), undefined, failed)
    delivery.accept(event('pending'))
    for (let i = 0; i < 257; i++) delivery.accept(event(`queue-${i}`))
    expect(failed).toHaveBeenCalledOnce()
    finish(); await Promise.resolve(); await Promise.resolve()
    expect(delivery.cursor()).toBeNull()
  })
})
