import { describe, expect, it, vi } from 'vitest'
import { startAppInteraction } from './app_interaction'

describe('app-scoped activity', () => {
  it('reports interaction but not blur, visibility, or page lifecycle', () => {
    const target = new EventTarget(), report = vi.fn()
    const stop = startAppInteraction(target, report)
    for (const name of ['blur', 'visibilitychange', 'pagehide', 'pageshow']) target.dispatchEvent(new Event(name))
    expect(report).not.toHaveBeenCalled()
    for (const name of ['pointerdown', 'pointermove', 'keydown', 'touchstart', 'wheel']) target.dispatchEvent(new Event(name))
    expect(report).toHaveBeenCalledTimes(5)
    stop(); target.dispatchEvent(new Event('keydown')); expect(report).toHaveBeenCalledTimes(5)
  })
})
