import { expect, it } from 'vitest'
import { browserSuppressionDisabled } from './capture_guard'

it('only confirms an explicit false browser suppression setting', () => {
  expect(browserSuppressionDisabled({ getSettings: () => ({ noiseSuppression: false }) } as MediaStreamTrack)).toBe(true)
  expect(browserSuppressionDisabled({ getSettings: () => ({ noiseSuppression: true }) } as MediaStreamTrack)).toBe(false)
  expect(browserSuppressionDisabled({ getSettings: () => ({}) } as MediaStreamTrack)).toBe(false)
  expect(browserSuppressionDisabled({ getSettings: () => { throw new Error('unavailable') } } as unknown as MediaStreamTrack)).toBe(false)
  expect(browserSuppressionDisabled(undefined)).toBe(false)
})
