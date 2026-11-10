import { createRealtimeDelivery, eventIdentity, type EventHandler } from '../realtime_event_delivery'
import type { RealtimeEvent } from '../realtime_client'
import { isSocialHint } from '../../conversation/reactions/hints'
export type HintBatchHandler = (events: RealtimeEvent[]) => Promise<void>
const hint = (event: RealtimeEvent) => !isSocialHint(event.kind) && (event.kind.startsWith('message.')
  || event.kind.startsWith('direct_message.message_') || event.kind === 'channel.updated')

export function createCoalescedDelivery(onEvent: EventHandler, recovery: EventHandlerRecovery,
  failure: (cause: unknown) => void, batch: HintBatchHandler) {
  let active = true, generation = 0, outstanding = 0, timer: ReturnType<typeof setTimeout> | null = null
  let pending: RealtimeEvent[] = []
  const seen = new Set<string>()
  const revocations = new Set<string>()
  const batches = new Map<RealtimeEvent, RealtimeEvent[]>()
  const immediate = new Map<RealtimeEvent, Promise<void>>()
  const base = createRealtimeDelivery(async event => {
    const group = batches.get(event)
    batches.delete(event)
    if (group) {
      const ownGeneration = generation
      const work = group.filter(item => !seen.has(eventIdentity(item)))
      if (work.length) await batch(work)
      if (active && ownGeneration === generation) {
        outstanding -= group.length
        for (const item of work) {
          seen.add(eventIdentity(item))
          if (seen.size > 2048) seen.delete(seen.values().next().value!)
        }
      }
    } else if (immediate.has(event)) {
      const work = immediate.get(event)
      immediate.delete(event)
      await work
    } else { if (event.kind === 'connection.resync_required') seen.clear(); await onEvent(event) }
  }, recovery, cause => {
    generation++; outstanding = 0
    if (timer !== null) clearTimeout(timer)
    timer = null; pending = []; batches.clear(); seen.clear(); immediate.clear(); revocations.clear(); failure(cause)
  })
  function flush(): void {
    if (timer !== null) clearTimeout(timer)
    timer = null
    if (!active || !pending.length) return
    const group = [...new Map(pending.map(event => [eventIdentity(event), event])).values()]
    outstanding -= pending.length - group.length
    pending = []
    const last = group[group.length-1]
    batches.set(last, group)
    base.accept(last)
  }
  return {
    accept(event: RealtimeEvent): void {
      if (!active || (hint(event) && seen.has(eventIdentity(event)))) return
      if (hint(event)) {
        if (outstanding >= 256) { base.abort(new Error('Realtime delivery overflow')); return }
        outstanding++
        pending.push(event)
        if (timer === null) timer = setTimeout(flush, 25)
        return
      }
      if (event.kind === 'voice.lease_revoked') {
        if (revocations.has(event.eventId)) return
        revocations.add(event.eventId)
        if (revocations.size > 2048) revocations.delete(revocations.values().next().value!)
        try { const work = Promise.resolve(onEvent(event)); void work.catch(() => {}); immediate.set(event, work) }
        catch (cause) { const work = Promise.reject<void>(cause); void work.catch(() => {}); immediate.set(event, work) }
      }
      if (!active) return
      flush()
      if (event.kind === 'connection.resync_required') seen.clear()
      base.accept(event)
    },
    cursor: base.cursor,
    disconnected: base.disconnected,
    reset(): void { active = false; generation++; outstanding = 0; if (timer !== null) clearTimeout(timer); pending = []; batches.clear(); immediate.clear(); seen.clear(); revocations.clear(); base.reset() },
  }
}
type EventHandlerRecovery = (() => void | Promise<void>) | undefined
