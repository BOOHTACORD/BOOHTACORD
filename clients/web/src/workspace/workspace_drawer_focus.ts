import { nextTick, onBeforeUnmount, onMounted, ref, watch, type Ref } from 'vue'

type Drawer = 'nav' | 'members' | 'search'
const focusableSelector = 'a[href], button, input, select, textarea, [tabindex]:not([tabindex="-1"])'

export function focusBoundaryTarget(items: HTMLElement[], current: Element | null, backwards: boolean): HTMLElement | null {
  if (!items.length) return null
  if (!items.includes(current as HTMLElement)) return backwards ? items[items.length - 1] : items[0]
  if (backwards && current === items[0]) return items[items.length - 1]
  if (!backwards && current === items[items.length - 1]) return items[0]
  return null
}

export function restorableDrawerFocusTarget(previous: HTMLElement | null, body: HTMLElement, html: HTMLElement, fallback: HTMLElement | null = null): HTMLElement | null {
  if (previous?.isConnected && previous !== body && previous !== html) return previous
  return fallback?.isConnected ? fallback : null
}

export function useWorkspaceDrawerFocus(
  navOpen: Ref<boolean>, membersOpen: Ref<boolean>, activePanel: Ref<string>, closeDrawers: () => void,
) {
  const modalDrawer = ref<Drawer | null>(null)
  let priorFocus: HTMLElement | null = null
  const priorInert = new Map<HTMLElement, boolean>()
  function panelFor(kind: Drawer): HTMLElement | null {
    return document.getElementById(kind === 'nav' ? 'nav-sidebar' : kind === 'members' ? 'members-panel' : 'search-aside-panel')
  }
  function restoreInert(): void {
    for (const [element, value] of priorInert) element.inert = value
    priorInert.clear()
  }
  function makeInert(element: HTMLElement | null): void {
    if (element && !priorInert.has(element)) { priorInert.set(element, element.inert); element.inert = true }
  }
  function focusables(panel: HTMLElement): HTMLElement[] {
    return Array.from(panel.querySelectorAll<HTMLElement>(focusableSelector)).filter((item) =>
      !item.matches(':disabled') && !item.closest('[inert]') && item.getClientRects().length > 0 && getComputedStyle(item).visibility !== 'hidden')
  }
  function visibleDrawer(): Drawer | null {
    const scrim = document.querySelector<HTMLElement>('.drawer-scrim')
    if (!scrim || getComputedStyle(scrim).display === 'none') return null
    return navOpen.value ? 'nav' : membersOpen.value ? 'members' : activePanel.value === 'search' ? 'search' : null
  }
  function syncFocus(): void {
    const next = visibleDrawer()
    if (next === modalDrawer.value) return
    const closed = modalDrawer.value
    restoreInert()
    modalDrawer.value = next
    if (next) {
      if (!closed) priorFocus = document.activeElement as HTMLElement | null
      const panel = panelFor(next)
      for (const id of ['nav-sidebar', 'main-region', 'members-panel', 'search-aside-panel']) {
        const sibling = document.getElementById(id)
        if (sibling !== panel) makeInert(sibling)
      }
      const entry = panel && (focusables(panel)[0] ?? panel.querySelector<HTMLElement>('.nav-drawer') ?? panel)
      entry?.focus()
    } else {
      const triggerSelector = closed === 'search'
        ? '.guild-search-button'
        : closed === 'nav'
          ? '.workspace-header-toggle--nav'
          : closed === 'members'
            ? '.workspace-header-toggle--members'
            : null
      const trigger = triggerSelector ? document.querySelector<HTMLElement>(triggerSelector) : null
      const target = (closed === 'nav' || closed === 'members') && trigger
        ? trigger
        : restorableDrawerFocusTarget(priorFocus, document.body, document.documentElement, trigger)
      target?.focus({ preventScroll: true })
      priorFocus = null
    }
  }
  function onKeydown(event: KeyboardEvent): void {
    if (event.key === 'Escape') {
      if (modalDrawer.value === 'search') activePanel.value = 'none'
      else if (navOpen.value || membersOpen.value) closeDrawers()
      return
    }
    if (event.key !== 'Tab' || !modalDrawer.value) return
    const panel = panelFor(modalDrawer.value)
    if (!panel) return
    const target = focusBoundaryTarget(focusables(panel), document.activeElement, event.shiftKey)
    if (target) { event.preventDefault(); target.focus() }
    else if (!focusables(panel).length) { event.preventDefault(); panel.focus() }
  }
  watch([navOpen, membersOpen, activePanel], () => { void nextTick(syncFocus) }, { flush: 'post' })
  onMounted(() => { window.addEventListener('keydown', onKeydown); void nextTick(syncFocus) })
  onBeforeUnmount(() => { window.removeEventListener('keydown', onKeydown); restoreInert() })
  return { modalDrawer }
}
