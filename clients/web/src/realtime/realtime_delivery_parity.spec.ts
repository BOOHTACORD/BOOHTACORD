import { describe, it, expect, vi } from 'vitest'
import { createRealtimeDelivery } from './realtime_event_delivery'
import type { RealtimeEvent } from './realtime_client'
import { subscribeSocialHints } from '../conversation/reactions/hints'
const event = (id: string): RealtimeEvent => ({ eventId: id, kind: 'message.updated', occurredAt: '2026-10-22T00:00:00Z', payload: {} })
describe('PAR-01 delivery regression', () => {
  it('reset prevents a late social observer from dispatching into another account scope', async () => {
    let finish!: () => void
    const stop=subscribeSocialHints(()=>new Promise<void>(resolve=>{finish=resolve}))
    const applied=vi.fn(), delivery=createRealtimeDelivery(applied,undefined,vi.fn())
    try {
      delivery.accept({...event('old'),kind:'message.pins_updated',payload:{channel_id:'11111111-1111-4111-8111-111111111111',message_id:'22222222-2222-4222-8222-222222222222'}})
      delivery.reset(); finish()
      await new Promise(resolve=>setTimeout(resolve,0))
      expect(applied).not.toHaveBeenCalled(); expect(delivery.cursor()).toBeNull()
    } finally {stop();delivery.reset()}
  })
  it('waits for social refresh before acknowledging and recovers on asynchronous observer failure', async () => {
    let finish!: () => void
    const stopped = subscribeSocialHints(() => new Promise<void>(resolve => { finish = resolve }))
    const applied = vi.fn(), failed = vi.fn()
    const delivery = createRealtimeDelivery(applied, undefined, failed)
    const social: RealtimeEvent = { ...event('social'), kind:'message.reactions_updated', payload:{channel_id:'11111111-1111-4111-8111-111111111111',message_id:'22222222-2222-4222-8222-222222222222'} }
    try {
      delivery.accept(social)
      expect(delivery.cursor()).toBeNull(); expect(applied).not.toHaveBeenCalled()
      finish(); await vi.waitFor(()=>expect(delivery.cursor()).toBe('social'))
    } finally { stopped(); delivery.reset() }
    const stopFailed = subscribeSocialHints(async () => { throw new Error('dependency unavailable') })
    try {
      const retrying = createRealtimeDelivery(vi.fn(), undefined, failed)
      retrying.accept(social)
      await vi.waitFor(()=>expect(failed).toHaveBeenCalledOnce())
      expect(retrying.cursor()).toBeNull()
      retrying.reset()
    } finally { stopFailed() }
  })
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
