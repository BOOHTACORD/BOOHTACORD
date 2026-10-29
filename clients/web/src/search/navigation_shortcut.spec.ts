import { describe, expect, it } from 'vitest'
import { shouldOpenSearchShortcut, type SearchShortcutEvent } from './search_shortcut'

function context() {
  const navigation = {}
  const nested = {}
  const target = { closest: (s: string) => s.includes('[role="dialog"]') ? navigation : null }
  const launcher = {
    closest: (s: string) => s.includes('[role="dialog"]') ? navigation : null,
    contains: (value: unknown) => value === target,
  }
  const event = (node: unknown, meta = false): SearchShortcutEvent => ({
    key: 'k', ctrlKey: !meta, metaKey: meta, altKey: false, shiftKey: false,
    repeat: false, isComposing: false, target: node,
  })
  return { navigation, nested, target, launcher, event }
}

describe('owned search launcher inside navigation dialog', () => {
  for (const meta of [false, true]) {
    it(`accepts the owned drawer launcher with ${meta ? 'Meta' : 'Ctrl'}+K`, () => {
      const c = context()
      expect(shouldOpenSearchShortcut(c.event(c.launcher, meta), c.launcher)).toBe(true)
      expect(shouldOpenSearchShortcut(c.event(c.target, meta), c.launcher)).toBe(true)
    })
  }

  it('keeps other navigation controls and ordinary content dialogs blocked', () => {
    const c = context()
    const unrelated = { closest: (s: string) => s.includes('[role="dialog"]') ? c.navigation : null }
    expect(shouldOpenSearchShortcut(c.event(unrelated), c.launcher)).toBe(false)
    const contentLauncher = { closest: (s: string) => !s.includes('#nav-sidebar') && s.includes('[role="dialog"]') ? c.nested : null }
    expect(shouldOpenSearchShortcut(c.event(contentLauncher), contentLauncher)).toBe(false)
    const nestedTarget = { closest: (s: string) => s.includes('[role="dialog"]') ? c.nested : null }
    const nestedLauncher = { ...c.launcher, contains: (value: unknown) => value === nestedTarget }
    expect(shouldOpenSearchShortcut(c.event(nestedTarget), nestedLauncher)).toBe(false)
  })

  it('never relaxes editable, composition, repeat or modifier guards', () => {
    const c = context()
    const editable = { closest: (s: string) => s.includes('input') ? {} : c.navigation }
    expect(shouldOpenSearchShortcut(c.event(editable), c.launcher)).toBe(false)
    for (const flags of [{ isComposing: true }, { repeat: true }, { altKey: true }, { shiftKey: true }]) {
      expect(shouldOpenSearchShortcut({ ...c.event(c.launcher), ...flags }, c.launcher)).toBe(false)
    }
  })

  it('keeps native HTML dialog controls blocked without an explicit role attribute', () => {
    const c = context()
    const nativeDialog = {}
    const control = { closest: (s: string) => s.split(',').map(value => value.trim()).includes('dialog') ? nativeDialog : null }
    expect(shouldOpenSearchShortcut(c.event(control), c.launcher)).toBe(false)
  })
})
