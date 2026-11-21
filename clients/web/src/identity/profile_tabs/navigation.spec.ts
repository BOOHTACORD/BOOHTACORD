import { afterEach, expect, it, vi } from 'vitest'
import { nextTick, ref } from 'vue'
import { createProfileTabKeydown } from './navigation'

afterEach(() => vi.unstubAllGlobals())

it('wraps profile tabs and focuses the selected tab while ignoring other keys', async () => {
  const focus = vi.fn(), lookup = vi.fn(() => ({ focus }))
  vi.stubGlobal('document', { getElementById: lookup })
  const active = ref('profile'), handler = createProfileTabKeydown(active, ['profile', 'security', 'about'])
  const preventDefault = vi.fn()
  handler({ key: 'ArrowLeft', preventDefault } as unknown as KeyboardEvent)
  expect(active.value).toBe('about')
  expect(preventDefault).toHaveBeenCalledOnce()
  await nextTick()
  expect(lookup).toHaveBeenCalledWith('profile-tab-about')
  expect(focus).toHaveBeenCalledOnce()
  handler({ key: 'Escape', preventDefault } as unknown as KeyboardEvent)
  expect(active.value).toBe('about')
  expect(preventDefault).toHaveBeenCalledOnce()
})

it.each([
  ['ArrowRight', 'security'],
  ['Home', 'profile'],
  ['End', 'about'],
])('handles %s without changing tab semantics', async (key, expected) => {
  vi.stubGlobal('document', { getElementById: () => ({ focus: vi.fn() }) })
  const active = ref('profile'), handler = createProfileTabKeydown(active, ['profile', 'security', 'about'])
  handler({ key, preventDefault: vi.fn() } as unknown as KeyboardEvent)
  expect(active.value).toBe(expected)
  await nextTick()
})
