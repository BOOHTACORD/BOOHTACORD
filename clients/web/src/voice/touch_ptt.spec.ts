import { describe, expect, it } from 'vitest'
import { supportsTouchPtt } from './touch_ptt'

describe('touch push-to-talk availability', () => {
  it('detects a phone by touch support or a coarse pointer', () => {
    expect(supportsTouchPtt({ maxTouchPoints: 1, coarsePointer: false })).toBe(true)
    expect(supportsTouchPtt({ maxTouchPoints: 0, coarsePointer: true })).toBe(true)
  })

  it('keeps keyboard assignment on a desktop pointer', () => {
    expect(supportsTouchPtt({ maxTouchPoints: 0, coarsePointer: false })).toBe(false)
  })
})
