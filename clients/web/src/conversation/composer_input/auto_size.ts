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
  watch(textarea, (element) => {
    if (!element) return
    syncComposerTextarea(element, draft.value)
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
