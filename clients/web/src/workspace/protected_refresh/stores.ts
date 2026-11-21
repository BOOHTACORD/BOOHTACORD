import type { WorkspaceRealtimeStores } from '../workspace_realtime'
import { createProtectedRefreshGate } from './gate'

export function coalesceStores(stores: WorkspaceRealtimeStores, gate: ReturnType<typeof createProtectedRefreshGate>): WorkspaceRealtimeStores {
  const { topology, messages, directMessages } = stores
  return {
    topology: { get error() { return topology.error }, refresh: () => gate.run('topology',
      () => topology.refreshRealtime ? topology.refreshRealtime(gate.current) : topology.refresh()) },
    messages: {
      get channelId() { return messages.channelId }, get error() { return messages.error },
      applyDeletedHint: (channelId, messageId) => messages.applyDeletedHint?.(channelId, messageId),
      refresh() {
        const id = messages.channelId
        return gate.run('text:'+id, async () => { if (messages.channelId === id) await messages.refresh() })
      },
    },
    directMessages: {
      get directMessageId() { return directMessages.directMessageId }, get error() { return directMessages.error },
      applyDeletedHint: (directMessageId, messageId) => directMessages.applyDeletedHint?.(directMessageId, messageId),
      refreshNavigation: () => gate.run('dm-navigation', () => directMessages.refreshNavigation()),
      refreshHistory() {
        const id = directMessages.directMessageId
        return gate.run('dm:'+id, async () => { if (directMessages.directMessageId === id) await directMessages.refreshHistory() })
      },
    },
  }
}
