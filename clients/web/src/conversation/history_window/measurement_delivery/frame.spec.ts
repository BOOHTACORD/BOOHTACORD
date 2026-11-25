import { afterEach, describe, expect, it, vi } from 'vitest'
import { createResizeDelivery } from './frame'

afterEach(() => vi.unstubAllGlobals())
function fixture() {
  let callback: FrameRequestCallback | undefined
  const request = vi.fn((next: FrameRequestCallback) => { callback = next; return 0 })
  const cancel = vi.fn(), deliver = vi.fn()
  vi.stubGlobal('requestAnimationFrame', request)
  vi.stubGlobal('cancelAnimationFrame', cancel)
  return { request, cancel, deliver, batch: createResizeDelivery(deliver),
    frame: () => { const next = callback; callback = undefined; next?.(0) } }
}
function entry(target: Element, height: number) {
  return { target, contentRect: { height } } as ResizeObserverEntry
}
describe('history measurement delivery', () => {
  it('defers layout writes and batches the latest observation for every target', () => {
    const f = fixture(), a = {} as Element, b = {} as Element
    f.batch.schedule([entry(a, 20)])
    f.batch.schedule([entry(b, 40), entry(a, 30)])
    expect(f.deliver).not.toHaveBeenCalled()
    expect(f.request).toHaveBeenCalledTimes(1)
    f.frame()
    expect(f.deliver).toHaveBeenCalledExactlyOnceWith([entry(a, 30), entry(b, 40)])
    f.batch.schedule([entry(a, 50)]); f.frame()
    expect(f.deliver).toHaveBeenLastCalledWith([entry(a, 50)])
  })
  it('does not deliver measurements for rows that were unobserved before the frame', () => {
    const f = fixture(), a = {} as Element, b = {} as Element
    f.batch.schedule([entry(a, 20), entry(b, 40)]); f.batch.forget(a); f.frame()
    expect(f.deliver).toHaveBeenCalledExactlyOnceWith([entry(b, 40)])
  })
  it('cancels a pending frame including handle zero and rejects delivery after disposal', () => {
    const f = fixture(), a = {} as Element
    f.batch.schedule([entry(a, 20)]); f.batch.dispose(); f.frame()
    f.batch.schedule([entry(a, 40)])
    expect(f.cancel).toHaveBeenCalledExactlyOnceWith(0)
    expect(f.deliver).not.toHaveBeenCalled()
    expect(f.request).toHaveBeenCalledTimes(1)
  })
})
