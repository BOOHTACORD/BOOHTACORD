import { onBeforeUnmount, watch, type Ref } from 'vue'

export function resizeComposerTextarea(textarea: HTMLTextAreaElement): void {
  textarea.style.height = 'auto'
  const style = getComputedStyle(textarea)
  const padding = parseFloat(style.paddingTop) + parseFloat(style.paddingBottom)
  const borders = parseFloat(style.borderTopWidth) + parseFloat(style.borderBottomWidth)
  const borderBox = style.boxSizing === 'border-box'
  const measuredHeight = textarea.scrollHeight
  const maxCssHeight = parseFloat(style.maxHeight)
  const maxClientHeight = Number.isFinite(maxCssHeight)
    ? maxCssHeight + (borderBox ? -borders : padding)
    : measuredHeight
  const clientHeight = Math.min(measuredHeight, maxClientHeight)

  textarea.style.height = `${Math.max(0, clientHeight + (borderBox ? borders : -padding))}px`
  const overflows = measuredHeight > clientHeight
  textarea.style.overflowY = overflows ? 'auto' : 'hidden'
  if (!overflows) textarea.scrollTop = 0
}

function syncComposerTextarea(textarea: HTMLTextAreaElement, draft: string): void {
  if (!draft || draft.includes('\n')) {
    textarea.style.height = ''
    textarea.style.overflowY = ''
    return
  }
  resizeComposerTextarea(textarea)
}

export function useComposerTextareaAutosize(draft: Ref<string>, textarea: Ref<HTMLTextAreaElement | null>): void {
  const resize = () => {
    if (textarea.value) syncComposerTextarea(textarea.value, draft.value)
  }
  watch(draft, (value) => {
    if (textarea.value) syncComposerTextarea(textarea.value, value)
  }, { flush: 'post' })
  watch(textarea, (element, _previous, onCleanup) => {
    if (!element) return
    syncComposerTextarea(element, draft.value)
    if (typeof ResizeObserver === 'undefined') return
    let width: number | undefined
    let frame: number | undefined
    const observer = new ResizeObserver(([entry]) => {
      if (!entry || entry.contentRect.width <= 0 || entry.contentRect.width === width) return
      width = entry.contentRect.width
      // Height updates must not feed another resize-observer delivery cycle.
      if (frame !== undefined) cancelAnimationFrame(frame)
      frame = requestAnimationFrame(() => {
        frame = undefined
        if (textarea.value === element) syncComposerTextarea(element, draft.value)
      })
    })
    observer.observe(element)
    onCleanup(() => {
      observer.disconnect()
      if (frame !== undefined) cancelAnimationFrame(frame)
    })
  }, { flush: 'post', immediate: true })
  if (typeof window !== 'undefined') {
    window.addEventListener('resize', resize)
    window.visualViewport?.addEventListener('resize', resize)
  }
  onBeforeUnmount(() => {
    if (typeof window !== 'undefined') {
      window.removeEventListener('resize', resize)
      window.visualViewport?.removeEventListener('resize', resize)
    }
  })
}
