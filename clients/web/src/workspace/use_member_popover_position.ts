import { computed, onBeforeUnmount, onMounted, ref, watch, type Ref } from 'vue'
import { placeMemberPopover } from './member_popover_position'

export function useMemberPopoverPosition(panel: Ref<HTMLElement | null>, content: Ref<HTMLElement | null>, anchor: () => HTMLElement | null) {
  const placement = ref({ x: 8, y: 64, width: 304, height: 0 })
  let frame = 0
  let observer: ResizeObserver | undefined
  function update(): void {
    const element = panel.value, trigger = anchor()
    if (!element || !trigger) return
    const viewport = window.visualViewport
    const box = { x: viewport?.offsetLeft ?? 0, y: viewport?.offsetTop ?? 0, width: viewport?.width ?? innerWidth, height: viewport?.height ?? innerHeight }
    const obstacles = Array.from(document.querySelectorAll<HTMLElement>('.conversation-header, .main-header, .composer-wrap, .voice-room-controls-bar, .voice-room-controls, .voice-room--mini, [data-testid="voice-dock"], .user-footer'))
      .filter(node => node.getClientRects().length && getComputedStyle(node).visibility !== 'hidden')
      .map(node => node.getBoundingClientRect())
    placement.value = placeMemberPopover(box, trigger.getBoundingClientRect(), { width: 304, height: (content.value?.getBoundingClientRect().height ?? 0) + 26 }, obstacles)
  }
  function schedule(): void { cancelAnimationFrame(frame); frame = requestAnimationFrame(update) }
  onMounted(() => {
    observer = new ResizeObserver(schedule)
    for (const element of [content.value, anchor(), ...document.querySelectorAll<HTMLElement>('.composer-wrap, .voice-room--mini, [data-testid="voice-dock"]')]) if (element) observer.observe(element)
    window.addEventListener('resize', schedule)
    document.addEventListener('scroll', schedule, true)
    window.visualViewport?.addEventListener('resize', schedule)
    window.visualViewport?.addEventListener('scroll', schedule)
    update()
  })
  watch(anchor, schedule)
  onBeforeUnmount(() => {
    cancelAnimationFrame(frame); observer?.disconnect()
    window.removeEventListener('resize', schedule)
    document.removeEventListener('scroll', schedule, true)
    window.visualViewport?.removeEventListener('resize', schedule)
    window.visualViewport?.removeEventListener('scroll', schedule)
  })
  return computed(() => ({ left: `${placement.value.x}px`, top: `${placement.value.y}px`, width: `${placement.value.width}px`, maxHeight: `${placement.value.height}px`, visibility: placement.value.height > 0 ? 'visible' as const : 'hidden' as const }))
}
