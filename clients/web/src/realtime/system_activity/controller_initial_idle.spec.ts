import { expect, it, vi } from 'vitest'
import { createSystemActivity } from './controller'

it('never reuses idle evidence after a suspended or backwards clock', async () => {
  vi.useFakeTimers()
  try {
    let now = 0
    const detector = Object.assign(new EventTarget(), {
      userState: 'idle' as const, screenState: 'unlocked' as const,
      start: async (_: { threshold: number; signal: AbortSignal }) => {},
    })
    const source = createSystemActivity({ available: true, create: () => detector,
      permission: async () => 'granted', report: () => {}, save: () => {}, now: () => now })
    await source.enable()
    for (let i = 0; i < 16; i++) { now += 15_000; vi.advanceTimersByTime(15_000) }
    expect(source.isConfirmedIdle()).toBe(true)
    now += 30_001
    expect(source.isConfirmedIdle()).toBe(false)
    now = -1
    expect(source.isConfirmedIdle()).toBe(false)
    source.stop()
  } finally { vi.useRealTimers() }
})

it('samples a five-minute detector immediately when restoring a previously idle browser', async () => {
  const normal = Object.assign(new EventTarget(), {
    userState: 'idle' as const, screenState: 'unlocked' as const,
    start: vi.fn(async (_: { threshold: number; signal: AbortSignal }) => {}),
  })
  const initial = Object.assign(new EventTarget(), {
    userState: 'idle' as const, screenState: 'unlocked' as const,
    start: vi.fn(async (_: { threshold: number; signal: AbortSignal }) => {}),
  })
  const source = createSystemActivity({ available: true, create: () => normal, createInitial: () => initial,
    permission: async () => 'granted', report: () => {}, save: () => {} })
  expect(await source.restore(async () => true)).toBe(true)
  expect(initial.start.mock.calls[0]![0].threshold).toBe(300_000)
  expect(source.isConfirmedIdle()).toBe(true)
  Object.assign(normal, { userState: 'active' })
  normal.dispatchEvent(new Event('change'))
  expect(source.isConfirmedIdle()).toBe(false)
  source.stop()
  expect(source.isConfirmedIdle()).toBe(false)
})

it('keeps the normal detector when the optional five-minute detector fails', async () => {
  const normal = Object.assign(new EventTarget(), {
    userState: 'active' as const, screenState: 'unlocked' as const,
    start: async (_: { threshold: number; signal: AbortSignal }) => {},
  })
  const initial = Object.assign(new EventTarget(), {
    userState: null, screenState: null,
    start: async (_: { threshold: number; signal: AbortSignal }) => { throw new Error('unavailable') },
  })
  const report = vi.fn()
  const source = createSystemActivity({ available: true, create: () => normal, createInitial: () => initial,
    permission: async () => 'granted', report, save: () => {} })
  expect(await source.enable()).toBe(true)
  expect(report).toHaveBeenCalledOnce()
  expect(source.isConfirmedIdle()).toBe(false)
  source.stop()
})

it('does not revive a detector when the five-minute sample resolves after disposal', async () => {
  let finish!: () => void
  const pending = new Promise<void>(resolve => { finish = resolve })
  const normal = Object.assign(new EventTarget(), {
    userState: 'idle' as const, screenState: 'unlocked' as const,
    start: async (_: { threshold: number; signal: AbortSignal }) => {},
  })
  const initial = Object.assign(new EventTarget(), {
    userState: 'idle' as const, screenState: 'unlocked' as const,
    start: (_: { threshold: number; signal: AbortSignal }) => pending,
  })
  const source = createSystemActivity({ available: true, create: () => normal, createInitial: () => initial,
    permission: async () => 'granted', report: () => {}, save: () => {} })
  const enabling = source.enable()
  await Promise.resolve(); await Promise.resolve(); await Promise.resolve()
  source.stop(); finish()
  expect(await enabling).toBe(false)
  expect(source.isConfirmedIdle()).toBe(false)
})
