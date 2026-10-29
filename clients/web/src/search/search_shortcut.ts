export interface SearchShortcutEvent {
  key: string
  ctrlKey: boolean
  metaKey: boolean
  altKey: boolean
  shiftKey: boolean
  repeat: boolean
  isComposing: boolean
  target: unknown
}

type ShortcutTarget = { closest?: (selectors: string) => unknown; contains?: (target: unknown) => boolean } | null

export function shouldOpenSearchShortcut(event: SearchShortcutEvent, launcher: unknown = null): boolean {
  if (event.key.toLowerCase() !== 'k' || (!event.ctrlKey && !event.metaKey) || event.altKey || event.shiftKey || event.repeat || event.isComposing) return false
  const target = event.target as ShortcutTarget
  if (target?.closest?.('input, textarea, select, [contenteditable]:not([contenteditable="false"]), [role="textbox"], [role="searchbox"]')) return false
  const dialog = target?.closest?.('[role="dialog"]')
  if (!dialog) return true
  const trigger = launcher as ShortcutTarget
  return Boolean(trigger && (target === trigger || trigger.contains?.(target)) &&
    dialog === trigger.closest?.('#nav-sidebar[role="dialog"]'))
}
