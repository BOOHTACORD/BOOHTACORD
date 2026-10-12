import { afterEach, describe, expect, it, vi } from 'vitest'
import { ref } from 'vue'
import { useWorkspaceDrawerFocus } from './workspace_drawer_focus'

const hooks = vi.hoisted(() => ({ watchers: [] as (() => void)[], cleanup: [] as (() => void)[] }))
vi.mock('vue', async importOriginal => ({
  ...await importOriginal<typeof import('vue')>(),
  onMounted: (callback: () => void) => callback(),
  onBeforeUnmount: (callback: () => void) => hooks.cleanup.push(callback),
  watch: (_source: unknown, callback: () => void) => { hooks.watchers.push(callback) },
}))

describe('open mobile navigation voice controls', () => {
  afterEach(() => {
    hooks.cleanup.splice(0).forEach(callback => callback())
    hooks.watchers.length = 0
    vi.unstubAllGlobals()
  })

  it('keeps the visible dock interactive and in the drawer Tab boundary, while background panels stay inert', async () => {
    let active: HTMLElement | null = null
    const dock = { inert: false } as HTMLElement
    const button = (insideDock = false): HTMLElement => ({
      inert: false,
      matches: () => false,
      closest: () => insideDock && dock.inert ? dock : null,
      getClientRects: () => [{}],
      focus: () => {},
    } as unknown as HTMLElement)
    // Bind focus closures to their own concrete controls.
    const first = button()
    const leave = button(true)
    first.focus = () => { active = first }
    leave.focus = () => { active = leave }
    const nav = { inert: false, querySelector: () => dock, querySelectorAll: () => [first, leave] } as unknown as HTMLElement
    const main = { inert: false } as HTMLElement
    const members = { inert: false } as HTMLElement
    const search = { inert: false } as HTMLElement
    const panels: Record<string, HTMLElement> = { 'nav-sidebar': nav, 'main-region': main, 'members-panel': members, 'search-aside-panel': search }
    let keydown: (event: KeyboardEvent) => void = () => {}
    vi.stubGlobal('document', { getElementById: (id: string) => panels[id], querySelector: () => ({}), get activeElement() { return active } })
    vi.stubGlobal('getComputedStyle', () => ({ display: 'block', visibility: 'visible' }))
    vi.stubGlobal('window', { addEventListener: (_: string, listener: typeof keydown) => { keydown = listener }, removeEventListener: () => {} })
    const navOpen = ref(true)
    useWorkspaceDrawerFocus(navOpen, ref(false), ref('none'), () => { navOpen.value = false })
    await Promise.resolve()
    expect(main.inert).toBe(true)
    expect(members.inert).toBe(true)
    expect(search.inert).toBe(true)
    expect(dock.inert).toBe(false)
    expect(active).toBe(first)
    const preventDefault = vi.fn()
    keydown({ key: 'Tab', shiftKey: true, preventDefault } as unknown as KeyboardEvent)
    expect(active).toBe(leave)
    expect(preventDefault).toHaveBeenCalledOnce()
  })
})
