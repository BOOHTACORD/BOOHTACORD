import { defineStore } from 'pinia'
import { onScopeDispose } from 'vue'
import type { RealtimeEvent } from '../../realtime/realtime_client'

export type ContextHint = { kind: 'CHANNEL' | 'DIRECT_MESSAGE'; conversationId: string; messageId: string; removed: boolean }
type Change = ContextHint | 'reset' | 'recovery'
type Listener = (hint: Change) => void | Promise<void>

// Pinia owns this observer set, so independent applications/accounts cannot
// share open context state through a module-global subscription.
export const useContextHints = defineStore('open-context-hints', () => {
  const listeners = new Set<Listener>()
  function subscribe(listener: Listener): () => void {
    listeners.add(listener); return () => { listeners.delete(listener) }
  }
  async function notify(hint: Change): Promise<void> {
    await Promise.all([...listeners].map(listener => listener(hint)))
  }
  function apply(event: RealtimeEvent): Promise<void> | undefined {
    const direct = event.kind.startsWith('direct_message.')
    if (!['message.updated', 'message.deleted', 'direct_message.message_updated', 'direct_message.message_deleted'].includes(event.kind)) return
    const conversationId = event.payload[direct ? 'direct_message_id' : 'channel_id'], messageId = event.payload.message_id
    if (typeof conversationId !== 'string' || typeof messageId !== 'string') return
    return notify({ kind: direct ? 'DIRECT_MESSAGE' : 'CHANNEL', conversationId, messageId, removed: event.kind.endsWith('deleted') })
  }
  function reset(): void {
    for (const listener of [...listeners]) void listener('reset')
    listeners.clear()
  }
  onScopeDispose(reset)
  return { subscribe, apply, reset, recover: () => notify('recovery') }
})

export function bindContextHints(hints: ReturnType<typeof useContextHints>,
  scope: { kind: 'CHANNEL' | 'DIRECT_MESSAGE'; conversationId: string; messageId: string },
  context: { open(id: string): Promise<void>; clear(): void; refreshMessage(id: string, removed?: boolean): Promise<void> }): () => void {
  return hints.subscribe(hint => {
    if (hint === 'reset') { context.clear(); return }
    if (hint === 'recovery') return context.open(scope.messageId)
    if (scope.kind === hint.kind && scope.conversationId === hint.conversationId) return context.refreshMessage(hint.messageId, hint.removed)
  })
}
