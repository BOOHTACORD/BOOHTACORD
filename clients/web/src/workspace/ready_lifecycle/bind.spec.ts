import { expect, it, vi } from 'vitest'
const hooks = vi.hoisted(() => ({ mount: vi.fn(), unmount: vi.fn(), observe: vi.fn() }))
vi.mock('vue', () => ({ onMounted: hooks.mount, onBeforeUnmount: hooks.unmount }))
vi.mock('../../telemetry/observe_render/workspace', () => ({ observeWorkspace: hooks.observe }))
import { bindWorkspaceReady } from './bind'

it('preserves startup, refresh, readiness cancellation and teardown ordering', async () => {
  const start = vi.fn(), refresh = vi.fn(async () => undefined), stop = vi.fn(), failed = vi.fn(() => false)
  bindWorkspaceReady({ start, refresh, stop, failed })
  expect(start).not.toHaveBeenCalled()
  hooks.mount.mock.calls[0][0]()
  expect(start).toHaveBeenCalledOnce()
  const [, load, active, failure] = hooks.observe.mock.calls[0]
  await load()
  expect(refresh).toHaveBeenCalledOnce()
  expect(active()).toBe(true)
  expect(failure).toBe(failed)
  hooks.unmount.mock.calls[0][0]()
  expect(active()).toBe(false)
  expect(stop).toHaveBeenCalledOnce()
})

it('waits for initial activity detection before connecting and never starts after disposal', async () => {
  let resolve!: () => void
  const ready = new Promise<void>(done => { resolve = done })
  const start = vi.fn(), stop = vi.fn()
  bindWorkspaceReady({ start, stop, refresh: async () => {}, failed: () => false, beforeStart: ready })
  hooks.mount.mock.calls.at(-1)![0]()
  expect(start).not.toHaveBeenCalled()
  resolve(); await Promise.resolve(); await Promise.resolve()
  expect(start).toHaveBeenCalledOnce()
  hooks.unmount.mock.calls.at(-1)![0]()
  expect(stop).toHaveBeenCalledOnce()
  let late!: () => void
  const delayed = new Promise<void>(done => { late = done }), cancelled = vi.fn()
  bindWorkspaceReady({ start: cancelled, stop: vi.fn(), refresh: async () => {}, failed: () => false, beforeStart: delayed })
  hooks.mount.mock.calls.at(-1)![0]()
  hooks.unmount.mock.calls.at(-1)![0]()
  late(); await Promise.resolve(); await Promise.resolve()
  expect(cancelled).not.toHaveBeenCalled()
})

it('bounds a stalled detector and does not start twice when it later resolves', async () => {
  vi.useFakeTimers()
  try {
    let resolve!: () => void
    const ready = new Promise<void>(done => { resolve = done }), start = vi.fn()
    bindWorkspaceReady({ start, stop: vi.fn(), refresh: async () => {}, failed: () => false, beforeStart: ready })
    hooks.mount.mock.calls.at(-1)![0]()
    vi.advanceTimersByTime(2_000)
    expect(start).toHaveBeenCalledOnce()
    resolve(); await Promise.resolve(); await Promise.resolve()
    expect(start).toHaveBeenCalledOnce()
    hooks.unmount.mock.calls.at(-1)![0]()
  } finally { vi.useRealTimers() }
})
