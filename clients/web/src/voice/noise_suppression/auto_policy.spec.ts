import { expect, it } from 'vitest'
import { selectAutoEngine } from './auto_policy'

it('selects the v0.2 research engine only when enabled and supported', () => {
  expect(selectAutoEngine({ v02: false, supported: true })).toBe('browser')
  expect(selectAutoEngine({ v02: true, supported: false })).toBe('browser')
  expect(selectAutoEngine({ v02: true, supported: true })).toBe('rnnoise')
})
