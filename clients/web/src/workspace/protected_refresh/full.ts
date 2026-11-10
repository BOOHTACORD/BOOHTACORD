import type { WorkspaceRealtimeStores } from './types'

export async function checked(refresh: () => Promise<void>, getError: () => string | null): Promise<void> {
  await refresh()
  if (getError()) throw new Error(getError()!)
}

export async function refreshProtectedState(stores: WorkspaceRealtimeStores): Promise<void> {
  const { topology, messages, directMessages } = stores
  const textActive = Boolean(messages.channelId && !directMessages.directMessageId)
  const directActive = Boolean(directMessages.directMessageId)
  await Promise.all([
    checked(() => topology.refresh(), () => topology.error),
    (async () => {
      await checked(() => directMessages.refreshNavigation(), () => directMessages.error)
      if (directActive) await checked(() => directMessages.refreshHistory(), () => directMessages.error)
    })(),
    textActive ? checked(() => messages.refresh(), () => messages.error) : Promise.resolve(),
  ])
}
