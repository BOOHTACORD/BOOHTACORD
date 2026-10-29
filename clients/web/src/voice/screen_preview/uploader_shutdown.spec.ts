import { describe, expect, it, vi } from 'vitest'
import { LatestScreenPreviewUploader } from './uploader'

const lease = '11111111-1111-4111-8111-111111111111'
const generation = '22222222-2222-4222-8222-222222222222'
const begun = () => Response.json({ schema_version: 1, generation_id: generation })
function deferred<T>() {
  let resolve!: (value: T) => void
  const promise = new Promise<T>((done) => { resolve = done })
  return { promise, resolve }
}

describe('screen preview uploader shutdown', () => {
  it('bounds a hung begin and invalidates a generation returned after stop', async () => {
    const pending = deferred<Response>(), methods: string[] = []
    let beginSignal: AbortSignal | undefined
    const request = vi.fn(async (_url: string, init: RequestInit) => {
      methods.push(init.method!)
      if (init.method === 'POST') { beginSignal = init.signal!; return pending.promise }
      return new Response(null, { status: 204 })
    })
    const uploader = new LatestScreenPreviewUploader(request)
    const starting = uploader.start(lease)
    vi.useFakeTimers()
    try {
      const stopping = uploader.stop()
      expect(beginSignal?.aborted).toBe(true)
      await vi.advanceTimersByTimeAsync(300)
      await expect(stopping).resolves.toBeUndefined()
      pending.resolve(begun())
      await starting
      expect(methods).toEqual(['POST', 'DELETE'])
    } finally { vi.useRealTimers() }
  })

  it('aborts a hung server-capture heartbeat and bounds leave', async () => {
    const pending = deferred<Response>(), refreshStarted = deferred<void>(), methods: string[] = []
    let refreshSignal: AbortSignal | undefined
    let posts = 0
    const request = vi.fn(async (_url: string, init: RequestInit) => {
      methods.push(init.method!)
      if (init.method === 'POST' && ++posts === 1) return begun()
      if (init.method === 'POST') { refreshSignal = init.signal!; refreshStarted.resolve(); return pending.promise }
      return new Response(null, { status: 204 })
    })
    const uploader = new LatestScreenPreviewUploader(request)
    vi.useFakeTimers()
    try {
      await uploader.start(lease)
      await vi.advanceTimersByTimeAsync(30_000)
      await refreshStarted.promise
      const stopping = uploader.stop()
      expect(refreshSignal?.aborted).toBe(true)
      await vi.advanceTimersByTimeAsync(300)
      await expect(stopping).resolves.toBeUndefined()
      pending.resolve(begun())
      await vi.waitFor(() => expect(methods).toEqual(['POST', 'POST', 'DELETE']))
    } finally { vi.useRealTimers() }
  })

  it('aborts a hung invalidation and returns from stop within its bound', async () => {
    const pending = deferred<Response>()
    let deleteSignal: AbortSignal | undefined
    const request = vi.fn(async (_url: string, init: RequestInit) => {
      if (init.method === 'POST') return begun()
      deleteSignal = init.signal!
      return pending.promise
    })
    const uploader = new LatestScreenPreviewUploader(request)
    await uploader.start(lease)
    vi.useFakeTimers()
    try {
      const stopping = uploader.stop()
      await vi.advanceTimersByTimeAsync(300)
      await expect(stopping).resolves.toBeUndefined()
      expect(deleteSignal?.aborted).toBe(true)
    } finally { vi.useRealTimers() }
  })
})
