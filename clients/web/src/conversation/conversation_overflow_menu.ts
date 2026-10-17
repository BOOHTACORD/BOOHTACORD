import { nextTick, ref } from 'vue'

export function useConversationOverflowMenu(openSearchAction: () => void, toggleMembersAction: () => void) {
  const expanded = ref(false)
  const root = ref<HTMLElement | null>(null)
  const trigger = ref<HTMLButtonElement | null>(null)
  const menu = ref<HTMLElement | null>(null)

  function close(restoreFocus = false): void {
    expanded.value = false
    if (restoreFocus) void nextTick(() => trigger.value?.focus())
  }

  function toggle(): void {
    expanded.value = !expanded.value
    if (expanded.value) void nextTick(() => menu.value?.querySelector<HTMLButtonElement>('[role="menuitem"]')?.focus())
  }

  function onOutside(event: PointerEvent): void {
    if (expanded.value && !root.value?.contains(event.target as Node)) close()
  }

  function onFocusOut(event: FocusEvent): void {
    if (expanded.value && !root.value?.contains(event.relatedTarget as Node)) close()
  }

  function onKeys(event: KeyboardEvent): void {
    if (!expanded.value) {
      if (event.key === 'ArrowDown' || event.key === 'ArrowUp') {
        event.preventDefault()
        expanded.value = true
        void nextTick(() => {
          const items = menu.value?.querySelectorAll<HTMLButtonElement>('[role="menuitem"]')
          items?.[event.key === 'ArrowUp' ? items.length - 1 : 0]?.focus()
        })
      }
      return
    }
    if (event.key === 'Escape') {
      event.stopPropagation()
      event.preventDefault()
      close(true)
      return
    }
    if (!['ArrowDown', 'ArrowUp', 'Home', 'End'].includes(event.key)) return
    const items = Array.from(menu.value?.querySelectorAll<HTMLButtonElement>('[role="menuitem"]') ?? [])
    if (!items.length) return
    event.preventDefault()
    const current = items.indexOf(document.activeElement as HTMLButtonElement)
    const next = event.key === 'Home' ? 0 : event.key === 'End' ? items.length - 1
      : current < 0 ? (event.key === 'ArrowDown' ? 0 : items.length - 1)
        : (current + (event.key === 'ArrowDown' ? 1 : -1) + items.length) % items.length
    items[next]?.focus()
  }

  function openSearch(): void { close(); openSearchAction() }
  function toggleMembers(): void { close(true); toggleMembersAction() }

  return { close, expanded, root, trigger, menu, toggle, onOutside, onFocusOut, onKeys, openSearch, toggleMembers }
}
