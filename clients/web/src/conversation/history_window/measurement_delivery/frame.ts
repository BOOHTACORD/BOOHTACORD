/** Apply observed sizes in the next rendering frame, outside ResizeObserver delivery. */
export function createResizeDelivery(deliver: (entries: ResizeObserverEntry[]) => void) {
  const pending = new Map<Element, ResizeObserverEntry>()
  let frame: number | undefined, disposed = false
  return {
    schedule(entries: ResizeObserverEntry[]): void {
      if (disposed || !entries.length) return
      for (const entry of entries) pending.set(entry.target, entry)
      frame ??= requestAnimationFrame(() => {
        frame = undefined
        if (disposed) return
        const current = [...pending.values()]
        pending.clear()
        if (current.length) deliver(current)
      })
    },
    forget: (element: Element) => { pending.delete(element) },
    dispose(): void {
      disposed = true
      if (frame !== undefined) cancelAnimationFrame(frame)
      frame = undefined
      pending.clear()
    },
  }
}
