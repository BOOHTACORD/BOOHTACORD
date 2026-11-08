import { describe, expect, it } from 'vitest'
import { shouldPreserveLatestPosition } from './follow_latest'

describe('virtual history resize anchoring', () => {
  it('keeps the bottom only while the reader is following latest', () => {
    const bottom = { scrollHeight: 1000, clientHeight: 500, scrollTop: 500 }
    expect(shouldPreserveLatestPosition(true, bottom)).toBe(true)
    expect(shouldPreserveLatestPosition(false, bottom)).toBe(false)
    expect(shouldPreserveLatestPosition(true, { ...bottom, scrollTop: 200 })).toBe(false)
  })
})
