import { afterEach, expect, it, vi } from 'vitest'
import { runWorker, type ProbeWorker } from './worker_runner'
afterEach(() => vi.useRealTimers())
function fixture() {
  const worker: ProbeWorker = { postMessage: vi.fn(), terminate: vi.fn(), onmessage: null, onerror: null, onmessageerror: null }
  const pending = runWorker({ synthetic: true }, () => worker)
  return { worker, pending }
}
it('terminates a worker after valid metrics and clears handlers', async () => {
  const f = fixture()
  f.worker.onmessage!({ data: { ready: true, p95Ms: 1, maxMs: 2, elapsedMs: 40, frames: 32 } } as MessageEvent)
  expect(await f.pending).toBe(true)
  expect(f.worker.terminate).toHaveBeenCalledOnce()
  expect(f.worker.onmessage).toBe(null)
})
it('rejects bad metrics and tears down on worker errors', async () => {
  const malformed = fixture()
  malformed.worker.onmessage!({ data: { ready: true } } as MessageEvent)
  expect(await malformed.pending).toBe(false)
  for (const kind of ['onerror', 'onmessageerror'] as const) {
    const f = fixture(); (f.worker[kind] as () => void)()
    expect(await f.pending).toBe(false)
    expect(f.worker.terminate).toHaveBeenCalledOnce()
  }
})
it('terminates a hung inference instead of waiting indefinitely', async () => {
  vi.useFakeTimers()
  const f = fixture()
  await vi.advanceTimersByTimeAsync(2000)
  expect(await f.pending).toBe(false)
  expect(f.worker.terminate).toHaveBeenCalledOnce()
})
it('fails closed on construction or postMessage failure', async () => {
  expect(await runWorker({}, () => { throw Error('blocked') })).toBe(false)
  const worker: ProbeWorker = { postMessage: () => { throw Error('clone') }, terminate: vi.fn(), onmessage: null, onerror: null, onmessageerror: null }
  expect(await runWorker({}, () => worker)).toBe(false)
  expect(worker.terminate).toHaveBeenCalledOnce()
})
