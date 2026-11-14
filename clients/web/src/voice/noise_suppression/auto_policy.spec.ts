import { expect, it } from 'vitest'
import { selectAutoEngine } from './capabilities'

it('selects the v0.2 research engine only when enabled and supported', () => {
  expect(selectAutoEngine({ v02: false, supported: true })).toBe('browser')
  expect(selectAutoEngine({ v02: true, supported: false })).toBe('browser')
  expect(selectAutoEngine({ v02: true, supported: true })).toBe('rnnoise')
})

it('selects DeepFilter only with explicit research opt-in and a supported environment', () => {
  expect(selectAutoEngine({ v02: true, supported: true, deepfilterResearch: true })).toBe('deepfilter')
  expect(selectAutoEngine({ v02: true, supported: false, deepfilterResearch: true })).toBe('browser')
  expect(selectAutoEngine({ v02: true, supported: true, deepfilterResearch: false })).toBe('rnnoise')
})
