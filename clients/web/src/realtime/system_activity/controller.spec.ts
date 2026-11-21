import { afterEach, describe, expect, it, vi } from 'vitest'
import { createSystemActivity } from './controller'

class Detector extends EventTarget {
  userState: 'active' | 'idle' | null = null
  screenState: 'locked' | 'unlocked' | null = null
  start = vi.fn(async (_options: { threshold: number; signal: AbortSignal }) => {})
  change(user: 'active' | 'idle', screen: 'locked' | 'unlocked') {
    this.userState = user; this.screenState = screen; this.dispatchEvent(new Event('change'))
  }
}

describe('system activity opt-in', () => {
  afterEach(() => vi.useRealTimers())
  function setup() {
    vi.useFakeTimers()
    const detector = new Detector(), report = vi.fn(), reportInactive = vi.fn(), save = vi.fn()
    const permission = vi.fn<() => Promise<PermissionState>>(async () => 'granted')
    const source = createSystemActivity({ available: true, create: () => detector, permission, report, reportInactive, save })
    return { detector, report, reportInactive, save, permission, source }
  }
  it('prompts only on explicit enable and reports only confirmed unlocked activity', async () => {
    const { detector, report, reportInactive, permission, source } = setup()
    expect(permission).not.toHaveBeenCalled()
    expect(await source.enable()).toBe(true)
    expect(permission).toHaveBeenCalledTimes(1)
    expect(detector.start).toHaveBeenCalledOnce()
    vi.advanceTimersByTime(30_000); expect(report).not.toHaveBeenCalled()
    detector.change('active', 'unlocked'); expect(report).toHaveBeenCalledTimes(1)
    vi.advanceTimersByTime(15_000); expect(report).toHaveBeenCalledTimes(2)
    detector.change('idle', 'unlocked'); vi.advanceTimersByTime(30_000)
    expect(reportInactive).toHaveBeenCalled()
    expect(source.allowAppInteraction()).toBe(true)
    detector.change('active', 'locked'); vi.advanceTimersByTime(30_000)
    expect(source.allowAppInteraction()).toBe(false)
    expect(report).toHaveBeenCalledTimes(2)
    detector.change('active', 'unlocked'); expect(report).toHaveBeenCalledTimes(3)
    expect(source.allowAppInteraction()).toBe(true)
    source.stop(); vi.advanceTimersByTime(30_000); expect(report).toHaveBeenCalledTimes(3)
  })
  it('denial leaves fallback active and does not install an observer', async () => {
    const { detector, permission, source, save } = setup()
    permission.mockResolvedValueOnce('denied')
    expect(await source.enable()).toBe(false)
    expect(detector.start).not.toHaveBeenCalled(); expect(save).not.toHaveBeenCalledWith(true)
  })
  it('disables reporting and aborts the current observer without duplicate timers', async () => {
    const { detector, source, report, save } = setup()
    await source.enable(); detector.change('active', 'unlocked')
    const signal = detector.start.mock.calls[0]![0].signal
    source.disable(); expect(signal.aborted).toBe(true); expect(save).toHaveBeenLastCalledWith(false)
    vi.advanceTimersByTime(60_000); expect(report).toHaveBeenCalledTimes(1)
  })
  it('does not prompt when unavailable', async () => {
    const permission = vi.fn(), report = vi.fn()
    const source = createSystemActivity({ available: false, create: () => new Detector(), permission, report, save: vi.fn() })
    expect(await source.enable()).toBe(false); expect(permission).not.toHaveBeenCalled()
  })
  it('restores only an already granted permission without prompting', async () => {
    const { detector, permission, source } = setup()
    expect(await source.restore(async () => false)).toBe(false)
    expect(permission).not.toHaveBeenCalled(); expect(detector.start).not.toHaveBeenCalled()
    expect(await source.restore(async () => true)).toBe(true)
    expect(permission).not.toHaveBeenCalled(); source.stop()
  })
  it('offers initial idle only after a fresh uninterrupted five-minute observation', async () => {
    const { detector, source } = setup()
    await source.enable()
    detector.change('idle', 'unlocked')
    vi.advanceTimersByTime(239_999)
    expect(source.isConfirmedIdle()).toBe(false)
    vi.advanceTimersByTime(1)
    expect(source.isConfirmedIdle()).toBe(true)
    detector.change('active', 'unlocked')
    expect(source.isConfirmedIdle()).toBe(false)
    source.stop()
  })
  it('does not leave an observer running if permission resolves after stop', async () => {
    const { detector, permission, source } = setup()
    let finish!: (state: PermissionState) => void
    permission.mockImplementationOnce(() => new Promise(resolve => { finish = resolve }))
    const pending = source.enable(); source.stop(); finish('granted')
    expect(await pending).toBe(false); expect(detector.start).not.toHaveBeenCalled()
  })
  it('falls back when starting the detector is rejected', async () => {
    const { detector, source, report } = setup()
    detector.start.mockRejectedValueOnce(new DOMException('policy', 'SecurityError'))
    expect(await source.enable()).toBe(false)
    detector.change('active', 'unlocked'); vi.advanceTimersByTime(60_000)
    expect(report).not.toHaveBeenCalled()
  })
  it('resamples after a long suspension instead of reporting the stale state', async () => {
    vi.useFakeTimers()
    let now = 0
    const detector = new Detector(), report = vi.fn()
    const source = createSystemActivity({ available: true, create: () => detector,
      permission: async () => 'granted', report, save: vi.fn(), now: () => now })
    await source.enable(); detector.change('active', 'unlocked')
    detector.userState = 'idle'
    now = 120_000; vi.advanceTimersByTime(15_000)
    await Promise.resolve()
    expect(report).toHaveBeenCalledTimes(1)
    expect(detector.start).toHaveBeenCalledTimes(2)
    detector.change('active', 'unlocked'); expect(report).toHaveBeenCalledTimes(2)
    source.stop()
  })
})
