interface ServerMessage { id: string; sendStatus?: 'sending' | 'checking' | 'failed' }
interface ScrollMetrics { scrollHeight: number; clientHeight: number; scrollTop: number }

export function newestServerMessageId(messages: readonly ServerMessage[]): string | undefined {
  return messages.find((message) => !message.sendStatus)?.id
}

export function newServerMessageCount(messages: readonly ServerMessage[], previousNewestId: string | undefined, wasLoaded: boolean): number {
  if (!wasLoaded) return 0
  const server = messages.filter((message) => !message.sendStatus)
  if (!previousNewestId) return server.length
  const previousIndex = server.findIndex((message) => message.id === previousNewestId)
  return previousIndex > 0 ? previousIndex : 0
}

export function shouldFollowNewestMessages(
  messages: readonly ServerMessage[],
  previousNewestId: string | undefined,
  wasLoaded: boolean,
  nearBottom: boolean,
): boolean {
  return nearBottom && newServerMessageCount(messages, previousNewestId, wasLoaded) > 0
}

export function isHistoryNearBottom(viewport: ScrollMetrics | null): boolean {
  return Boolean(viewport && viewport.scrollHeight - viewport.clientHeight - viewport.scrollTop <= 96)
}
