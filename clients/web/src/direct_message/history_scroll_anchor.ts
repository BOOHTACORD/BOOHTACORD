import { onBeforeUnmount, onMounted, onUpdated, type Ref } from 'vue'
import { isHistoryNearBottom } from '../conversation/new_message_jump'

interface Anchor { row: HTMLElement; offset: number; bottom: boolean }

export function useDirectMessageScrollAnchor(root: Ref<HTMLOListElement | null>) {
  let anchor: Anchor | undefined, anchoredScrollTop = 0, observer: ResizeObserver | undefined
  const observed = new Set<Element>()

  function capture(): Anchor | undefined {
    const viewport = root.value
    if (!viewport) return undefined
    const top = viewport.getBoundingClientRect().top
    const row = [...viewport.querySelectorAll<HTMLElement>('[data-message-id]')].find(item => {
      const bounds = item.getBoundingClientRect()
      return bounds.bottom > top && bounds.top < top + viewport.clientHeight
    })
    anchor = row ? { row, offset: row.getBoundingClientRect().top - top, bottom: isHistoryNearBottom(viewport) } : undefined
    anchoredScrollTop = viewport.scrollTop
    return anchor
  }

  function restore(saved = anchor): void {
    const viewport = root.value
    if (!viewport) return
    if (!saved || !viewport.contains(saved.row)) { capture(); return }
    anchor = saved
    if (saved.bottom) viewport.scrollTop = viewport.scrollHeight
    else viewport.scrollTop += saved.row.getBoundingClientRect().top - viewport.getBoundingClientRect().top - saved.offset
    // A scroll event from our own correction must not replace the reading anchor
    // with a newly prepended row whose reactions may still be loading.
    anchoredScrollTop = viewport.scrollTop
  }

  function onScroll(): void {
    if (!anchor || Math.abs((root.value?.scrollTop ?? 0) - anchoredScrollTop) > 0.5) capture()
  }

  function observeRows(): void {
    const viewport = root.value
    if (!observer || !viewport) return
    for (const element of observed) if (!viewport.contains(element)) { observer.unobserve(element); observed.delete(element) }
    for (const element of [viewport, ...viewport.querySelectorAll('[data-message-id]')]) {
      if (!observed.has(element)) { observer.observe(element, { box: 'border-box' }); observed.add(element) }
    }
  }
  onMounted(() => {
    capture()
    if (typeof ResizeObserver !== 'undefined') { observer = new ResizeObserver(() => restore()); observeRows() }
  })
  onUpdated(observeRows)
  onBeforeUnmount(() => { observer?.disconnect(); observed.clear(); anchor = undefined })
  return { capture, restore, onScroll }
}
