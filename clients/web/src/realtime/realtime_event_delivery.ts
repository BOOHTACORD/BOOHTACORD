import type { RealtimeEvent } from './realtime_client'
import { applySocialHint,applySocialRecovery } from '../conversation/reactions/hints'

export type EventHandler = (event: RealtimeEvent) => void | Promise<void>
type RecoveryHandler = () => void | Promise<void>

const durableKinds = new Set<RealtimeEvent['kind']>([
  'voice.lease_revoked', 'channel.updated', 'message.created', 'message.updated', 'message.deleted',
  'direct_message.message_created', 'direct_message.message_updated', 'direct_message.message_deleted',
  'message.reactions_updated','message.pins_updated','direct_message.reactions_updated',
])

export function createRealtimeDelivery(onEvent: EventHandler, onRecovery: RecoveryHandler | undefined, onFailure: (cause: unknown) => void) {
  let cursor: string | null = null
  let fullResyncNeeded = true
  let epoch = 0
  let busy = false
  let active = true
  const queue: RealtimeEvent[] = []
  const seen = new Set<string>()

  function remember(id: string): void {
    seen.add(id)
    if (seen.size > 2048) seen.delete(seen.values().next().value!)
    cursor = id
  }

  function pump(): void {
    if (!active || busy) return
    while (queue.length) {
      const event = queue.shift()!
      const durable = durableKinds.has(event.kind)
      if (durable && seen.has(event.eventId)) continue
      const generation = epoch
      const current=()=>active&&generation===epoch
      const chain=(work:void|Promise<void>,next:()=>void|Promise<void>):void|Promise<void> =>
        work ? work.then(()=>current()?next():undefined) : current()?next():undefined
      let work: void | Promise<void>
      try {
        if (event.kind === 'connection.resync_required') {
          cursor = null
          seen.clear()
          fullResyncNeeded = true
          work = chain(onEvent(event),applySocialRecovery)
        } else if (event.kind === 'connection.ready') {
          if (!fullResyncNeeded) continue
          work = chain(onRecovery?.(),applySocialRecovery)
        } else {
          work = chain(applySocialHint(event),()=>onEvent(event))
        }
      } catch (cause) { fail(cause); return }
      const complete = () => {
        if (!active || generation !== epoch) return
        if (durable) remember(event.eventId)
        if (event.kind === 'connection.ready' || event.kind === 'connection.resync_required') fullResyncNeeded = false
      }
      if (work && typeof work.then === 'function') {
        busy = true
        void Promise.resolve(work).then(() => { if (generation !== epoch) return; complete(); busy = false; pump() }, (cause) => { if (generation === epoch) fail(cause) })
        return
      }
      complete()
    }
  }

  function fail(cause: unknown): void {
    epoch++
    busy = false
    queue.length = 0
    cursor = null
    seen.clear()
    fullResyncNeeded = true
    if (active) onFailure(cause)
  }

  return {
    accept(event: RealtimeEvent): void { if (!active) return; if (queue.length >= 256) { fail(new Error('Realtime delivery overflow')); return }; queue.push(event); pump() },
    cursor(): string | null { return cursor },
    disconnected(): void { if (!cursor) fullResyncNeeded = true },
    reset(): void { active = false; queue.length = 0; cursor = null; seen.clear() },
  }
}
