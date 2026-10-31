import { computed, nextTick, onBeforeUnmount, onMounted, onUpdated, ref, watch, type ComputedRef, type CSSProperties, type Ref } from 'vue'
import { buildVirtualOffsets, findVirtualRange, type HistoryRow, type RenderedRow } from './window'
import { useEditingPin } from './editing_pin'

export function useHistoryWindow<T extends HistoryRow>(rows: ComputedRef<T[]>, root: Ref<HTMLOListElement | null>, hasOlder: ComputedRef<boolean>, compact: Ref<boolean>, isEditing?: (id: string) => boolean) {
  const measured = ref(new Map<string, number>()), scrollTop = ref(0), viewportHeight = ref(600)
  const paddingTop = ref(20), paddingLeft = ref(24), paddingRight = ref(24), controlHeight = ref(0)
  const focusedMessage = ref<string>(), editingPin = useEditingPin(rows, root)
  const offsets = computed(() => buildVirtualOffsets(rows.value, measured.value))
  const rowIndex = computed(() => new Map(rows.value.flatMap((row, index) => row.messageId ? [[row.messageId, index] as const] : [])))
  const rowsByKey = computed(() => new Map(rows.value.map((row) => [row.key, row])))
  const range = computed(() => findVirtualRange(offsets.value, Math.max(0, scrollTop.value - paddingTop.value - controlHeight.value), viewportHeight.value))
  const renderedRows = computed<RenderedRow<T>[]>(() => {
    const current = range.value, output = rows.value.slice(current.start, current.end).map((row, index) => ({ ...row, index: current.start + index, pinned: false }))
    const pin = editingPin.row.value
    const pinIndex = rowIndex.value.get((isEditing ? focusedMessage.value ?? pin?.messageId : pin?.messageId ?? focusedMessage.value) ?? '')
    if (pinIndex !== undefined && (pinIndex < current.start || pinIndex >= current.end)) output.push({ ...rows.value[pinIndex]!, index: pinIndex, pinned: true })
    else if (isEditing && pin && pinIndex === undefined) output.push({ ...pin, index: -1, pinned: true, detached: true })
    return output.sort((left, right) => left.index - right.index)
  })
  const topSpacer = computed(() => range.value.top), bottomSpacer = computed(() => range.value.bottom)
  let observer: ResizeObserver | undefined
  const observed = new Set<Element>()

  function readViewport(): void {
    const element = root.value
    if (!element) return
    const css = getComputedStyle(element)
    paddingTop.value = Number.parseFloat(css.paddingTop) || 0
    paddingLeft.value = Number.parseFloat(css.paddingLeft) || 0
    paddingRight.value = Number.parseFloat(css.paddingRight) || 0
    viewportHeight.value = element.clientHeight || viewportHeight.value
    if (hasOlder.value && !controlHeight.value) controlHeight.value = 44
    compact.value = window.matchMedia?.('(max-width: 1023px)').matches ?? false
  }
  function syncScroll(): void { scrollTop.value = root.value?.scrollTop ?? 0; viewportHeight.value = root.value?.clientHeight || viewportHeight.value }
  function observeRows(): void {
    if (!observer || !root.value) return
    for (const element of observed) if (!root.value.contains(element)) { observer.unobserve(element); observed.delete(element) }
    root.value.querySelectorAll('[data-virtual-key], [data-history-control]').forEach((element) => {
      if (!observed.has(element)) { observed.add(element); observer!.observe(element) }
    })
  }
  function pinFocused(event: FocusEvent): void {
    const row = (event.target as HTMLElement | null)?.closest<HTMLElement>('[data-message-id], [data-retained-message-id]')
    focusedMessage.value = row?.dataset.messageId ?? row?.dataset.retainedMessageId
    editingPin.rememberFocus(focusedMessage.value)
    if (focusedMessage.value && isEditing?.(focusedMessage.value)) editingPin.setEditing(focusedMessage.value, true)
  }
  function releaseFocus(): void {
    void nextTick(() => {
      const row = document.activeElement?.closest<HTMLElement>('[data-message-id], [data-retained-message-id]')
      focusedMessage.value = row?.dataset.messageId ?? row?.dataset.retainedMessageId
      if (document.activeElement !== document.body) editingPin.rememberFocus(focusedMessage.value)
    })
  }
  function clearPins(): void { editingPin.clear(); focusedMessage.value = undefined }
  function indexOf(messageId: string): number | undefined { return rowIndex.value.get(messageId) }
  function offsetOf(messageId: string): number | undefined { const index = indexOf(messageId); return index === undefined ? undefined : paddingTop.value + controlHeight.value + offsets.value[index]! }
  function scrollToMessage(messageId: string): boolean {
    const offset = offsetOf(messageId), element = root.value
    if (offset === undefined || !element) return false
    element.scrollTop = Math.max(0, offset - Math.round(element.clientHeight / 3)); syncScroll(); return true
  }
  function rowStyle(row: RenderedRow<T>): CSSProperties {
    if (row.detached) return { position: 'absolute', top: '0', left: '0', width: '1px', height: '1px', overflow: 'hidden', clipPath: 'inset(50%)' }
    const spacing = `${row.gap}px`
    return row.pinned ? { position: 'absolute', top: `${offsetOf(row.messageId ?? '') ?? 0}px`, left: `${paddingLeft.value}px`, right: `${paddingRight.value}px`, paddingTop: spacing } : { paddingTop: spacing }
  }
  function resize(entries: ResizeObserverEntry[]): void {
    const next = new Map(measured.value)
    for (const entry of entries) {
      const element = entry.target as HTMLElement, key = element.dataset.virtualKey
      const row = key ? rowsByKey.value.get(key) : undefined
      const height = element.getBoundingClientRect().height - (row?.gap ?? 0)
      if (key && row && height > 0 && Math.abs((next.get(key) ?? 0) - height) > 0.5) next.set(key, height)
      if (element.hasAttribute('data-history-control') && height > 0) controlHeight.value = height
    }
    if (next.size !== measured.value.size || [...next].some(([key, value]) => measured.value.get(key) !== value)) {
      const keepBottom = Boolean(root.value && root.value.scrollHeight - root.value.clientHeight - root.value.scrollTop <= 96)
      measured.value = next
      if (keepBottom) void nextTick(() => { if (root.value) { root.value.scrollTop = root.value.scrollHeight; syncScroll() } })
    }
  }
  onMounted(() => { readViewport(); if (typeof ResizeObserver !== 'undefined') { observer = new ResizeObserver(resize); if (root.value) observer.observe(root.value); observeRows() }; window.addEventListener('resize', readViewport) })
  watch(hasOlder, (hasPage) => { controlHeight.value = hasPage ? 44 : 0 })
  watch(rows, (current) => {
    const keys = new Set(current.map((row) => row.key))
    if ([...measured.value.keys()].some((key) => !keys.has(key))) measured.value = new Map([...measured.value].filter(([key]) => keys.has(key)))
  })
  watch(rowIndex, (index) => {
    if (!isEditing && editingPin.row.value?.messageId && !index.has(editingPin.row.value.messageId)) editingPin.clear()
    if (focusedMessage.value && !index.has(focusedMessage.value)) focusedMessage.value = undefined
  })
  watch(() => { const id = editingPin.row.value?.messageId; return id && isEditing ? isEditing(id) : undefined }, (active) => {
    if (active === false) editingPin.clear()
  }, { flush: 'sync' })
  onUpdated(observeRows)
  onBeforeUnmount(() => { observer?.disconnect(); observed.clear(); window.removeEventListener('resize', readViewport) })
  return { compact, range, renderedRows, topSpacer, bottomSpacer, readViewport, syncScroll, pinFocused, releaseFocus, setEditing: editingPin.setEditing, clearPins, offsetOf, scrollToMessage, rowStyle }
}
