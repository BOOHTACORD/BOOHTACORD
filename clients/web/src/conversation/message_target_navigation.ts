const flashTimers = new WeakMap<HTMLElement, number>()

export function highlightMessageTarget(row: HTMLElement): void {
  const previousTimer = flashTimers.get(row)
  if (previousTimer !== undefined) window.clearTimeout(previousTimer)
  row.classList.remove('message-search-target')
  // Restart the flash animation when the same result is opened twice.
  void row.offsetWidth
  row.classList.add('message-search-target')
  const timer = window.setTimeout(() => {
    row.classList.remove('message-search-target')
    flashTimers.delete(row)
  }, 1800)
  flashTimers.set(row, timer)
}

export function scrollToMessageTarget(viewport: HTMLElement | null, messageId: string): boolean {
  const row = [...(viewport?.querySelectorAll<HTMLElement>('[data-message-id]') ?? [])]
    .find((item) => item.dataset.messageId === messageId)
  if (!row) return false
  row.scrollIntoView({ block: 'center', behavior: window.matchMedia?.('(prefers-reduced-motion: reduce)').matches ? 'auto' : 'smooth' })
  highlightMessageTarget(row)
  return true
}
