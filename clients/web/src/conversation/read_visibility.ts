interface ReadMessage { id: string; sendStatus?: 'sending' | 'checking' | 'failed' }

export function firstUnreadIsVisible(viewport: HTMLElement | null, messageId?: string): boolean {
  if (!messageId) return true
  if (!viewport || viewport.clientHeight <= 0) return false
  const bounds = viewport.getBoundingClientRect()
  if (bounds.bottom <= bounds.top) return false
  return [...viewport.querySelectorAll<HTMLElement>('[data-message-id]')].some((row) => {
    if (row.dataset.messageId !== messageId) return false
    const rect = row.getBoundingClientRect()
    return rect.bottom > bounds.top && rect.top < bounds.bottom
  })
}

export function newestVisibleServerMessageId(viewport: HTMLElement | null, messages: readonly ReadMessage[]): string | undefined {
  if (!viewport || viewport.clientHeight <= 0) return undefined
  const bounds = viewport.getBoundingClientRect()
  if (bounds.bottom <= bounds.top) return undefined
  const visible = new Set([...viewport.querySelectorAll<HTMLElement>('[data-message-id]')]
    .filter((row) => {
      const rect = row.getBoundingClientRect()
      return rect.bottom > bounds.top && rect.top < bounds.bottom
    })
    .map((row) => row.dataset.messageId))
  return messages.find((message) => !message.sendStatus && visible.has(message.id))?.id
}

export function shouldAdvanceVisibleRead(messages: readonly ReadMessage[], previousKey: string, conversationId: string, candidateId: string): boolean {
  const prefix = `${conversationId}:`
  if (!previousKey.startsWith(prefix)) return true
  const previousIndex = messages.findIndex((message) => message.id === previousKey.slice(prefix.length))
  const candidateIndex = messages.findIndex((message) => message.id === candidateId)
  return previousIndex < 0 || (candidateIndex >= 0 && candidateIndex < previousIndex)
}
