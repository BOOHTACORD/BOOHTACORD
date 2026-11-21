import { expect, it } from 'vitest'
import { createActivityThrottle } from './throttle'

it('uses elapsed time, accepts the first report, and retries failed sends', () => {
  let now = 0
  const throttle = createActivityThrottle(() => now)
  expect(throttle.ready()).toBe(true); expect(throttle.ready()).toBe(true)
  throttle.sent(); now = 9_999; expect(throttle.ready()).toBe(false)
  now = 10_000; expect(throttle.ready()).toBe(true)
  throttle.sent(); now = 0; expect(throttle.ready()).toBe(true)
})
