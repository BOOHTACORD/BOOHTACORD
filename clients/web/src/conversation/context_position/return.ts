import { nextTick, onBeforeUnmount, watch, type Ref } from 'vue'
import { draftKey, draftMemoryEpoch } from '../draft_memory'
import { capture, restore, type Position } from './dom'
import { loadPosition, savePosition } from './memory'

export function useContextPosition(accountId: string, kind: 'CHANNEL' | 'DIRECT_MESSAGE', scope: () => string,
  root: Ref<HTMLElement | null>, contextOpen: () => boolean, loaded: () => boolean,
  restoreMissing: (position: Position) => Promise<void>) {
  const epoch = draftMemoryEpoch()
  let key = draftKey(accountId, kind, scope()), previous: Position | null = null, focus: HTMLElement | null = null
  let restoreSequence = 0
  const main = () => root.value?.querySelector<HTMLElement>('.message-history-wrap .message-list') ?? null
  function save(): void {
    if (epoch !== draftMemoryEpoch()) return
    const context = root.value?.querySelector<HTMLElement>('.search-context-list')
    const viewport = context?.clientHeight ? context : main()
    const position = capture(viewport)
    if (position) savePosition(key, position)
  }
  async function restorePosition(position: Position): Promise<void> {
    if (restore(main(), position)) return
    await restoreMissing(position)
  }
  async function restoreSavedPosition(): Promise<void> {
    const sequence = ++restoreSequence
    const requestKey = key
    await nextTick()
    if (sequence !== restoreSequence || requestKey !== key || epoch !== draftMemoryEpoch() || !loaded()) return
    const target = loadPosition(requestKey)
    if (!target) return
    if (contextOpen()) { previous = target; return }
    await restorePosition(target)
  }
  watch(contextOpen, async (open, wasOpen) => {
    if (open && !wasOpen) { previous = capture(main()); focus = document.activeElement instanceof HTMLElement ? document.activeElement : null }
    if (!open && wasOpen) {
      await nextTick()
      if (previous) await restorePosition(previous)
      if (focus?.isConnected) focus.focus({ preventScroll: true })
      else root.value?.querySelector<HTMLElement>('textarea')?.focus({ preventScroll: true })
    }
  }, { flush: 'pre' })
  watch(scope, () => { save(); key = draftKey(accountId, kind, scope()); previous = null; void restoreSavedPosition() }, { flush: 'pre' })
  watch(loaded, async ready => {
    if (!ready) return
    await restoreSavedPosition()
  }, { immediate: true, flush: 'post' })
  onBeforeUnmount(save)
  async function showLatest(): Promise<void> {
    previous = null
    await nextTick()
    const viewport = main()
    if (viewport) viewport.scrollTop = viewport.scrollHeight
  }
  return { save, showLatest }
}
