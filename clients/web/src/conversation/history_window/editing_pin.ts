import { nextTick, onScopeDispose, shallowRef, watch, type ComputedRef, type Ref } from 'vue'
import type { HistoryRow } from './window'

export function useEditingPin<T extends HistoryRow>(rows: ComputedRef<T[]>, root: Ref<HTMLOListElement | null>) {
  const row = shallowRef<T>()
  let focusedOwner: string | undefined, version = 0
  function clear(): void { row.value = undefined; focusedOwner = undefined; version++ }
  onScopeDispose(clear)
  watch(rows, (current) => {
    if (!row.value?.messageId) return
    const latest = current.find((item) => item.messageId === row.value?.messageId)
    if (latest) row.value = latest
  }, { flush: 'sync' })
  function setEditing(messageId: string, editing: boolean): void {
    const detached = row.value?.messageId === messageId && !rows.value.some((item) => item.messageId === messageId)
    const element = detached ? [...(root.value?.querySelectorAll<HTMLElement>('[data-message-id], [data-retained-message-id]') ?? [])]
      .find((item) => (item.dataset.messageId ?? item.dataset.retainedMessageId) === messageId) : undefined
    const restoreFocus = !editing && Boolean(element && (element.contains(document.activeElement)
      || document.activeElement === document.body && focusedOwner === messageId))
    if (editing) {
      const latest = rows.value.find((item) => item.messageId === messageId)
      if (latest) row.value = latest
    } else if (row.value?.messageId === messageId) clear()
    const currentVersion = version
    if (restoreFocus) void nextTick(() => {
      if (version !== currentVersion || document.activeElement !== document.body) return
      root.value?.querySelector<HTMLElement>('[data-history-control] button:not(:disabled), .message-row')?.focus()
    })
  }
  return { row, setEditing, clear, rememberFocus: (id?: string) => { focusedOwner = id } }
}
