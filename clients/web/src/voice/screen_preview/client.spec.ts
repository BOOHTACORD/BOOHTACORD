import { describe, expect, it, vi } from 'vitest'
import { apiBaseUrl } from '../../config/runtime'
import { beginScreenPreview, readScreenPreview, type ScreenPreviewHint, type ScreenPreviewRequest } from './client'
import { LatestScreenPreviewReader } from './reader'
import { LatestScreenPreviewUploader } from './uploader'

const lease = '11111111-1111-4111-8111-111111111111'
const generation = '22222222-2222-4222-8222-222222222222'
const hint: ScreenPreviewHint = { leaseId: lease, generationId: generation, revision: 1 }
const jpeg = new Uint8Array([0xff, 0xd8, 0xff, 0xd9])

describe('private screen preview client', () => {
  it('mints generations through same-origin no-store requests', async () => {
    const request = vi.fn(async () => Response.json({ schema_version: 1, generation_id: generation }))
    await expect(beginScreenPreview(lease, request)).resolves.toBe(generation)
    expect(request).toHaveBeenCalledWith(`${apiBaseUrl}/voice/leases/${lease}/screen-previews/v1`, expect.objectContaining({ method: 'POST', credentials: 'same-origin', cache: 'no-store' }))
  })

  it('reads protected JPEG bytes and honors no-update responses', async () => {
    const frame = new Response(jpeg, { headers: { 'content-type': 'image/jpeg', 'X-Screen-Preview-Revision': '2' } })
    await expect(readScreenPreview(hint, 0, vi.fn(async () => frame))).resolves.toMatchObject({ revision: 2, bytes: jpeg })
    await expect(readScreenPreview(hint, 2, vi.fn(async () => new Response(null, { status: 204 })))).resolves.toBeNull()
  })

  it('coalesces hints while one protected read is in flight', async () => {
    let finish!: (response: Response) => void
    const request = vi.fn().mockImplementationOnce(() => new Promise<Response>(resolve => { finish = resolve }))
      .mockResolvedValueOnce(new Response(jpeg, { headers: { 'content-type': 'image/jpeg', 'X-Screen-Preview-Revision': '2' } }))
    const applied: number[] = []
    const reader = new LatestScreenPreviewReader({ apply: (_hint, bytes) => applied.push(bytes.length), clear: vi.fn() }, request)
    reader.accept(hint)
    reader.accept({ ...hint, revision: 2 })
    finish(new Response(jpeg, { headers: { 'content-type': 'image/jpeg', 'X-Screen-Preview-Revision': '1' } }))
    await vi.waitFor(() => expect(request).toHaveBeenCalledTimes(2))
    expect(applied).toEqual([4])
    expect(request).toHaveBeenCalledTimes(2)
    reader.clear()
  })

  it('refreshes the server-owned capture every 30 seconds without uploading frames', async () => {
    const methods: string[] = []
    const request: ScreenPreviewRequest = async (_input, init) => {
      methods.push(init.method!)
      return init.method === 'POST'
        ? Response.json({ schema_version: 1, generation_id: generation })
        : new Response(null, { status: 204 })
    }
    const uploader = new LatestScreenPreviewUploader(request)
    vi.useFakeTimers()
    try {
      await uploader.start(lease)
      await vi.advanceTimersByTimeAsync(30_000)
      await vi.waitFor(() => expect(methods).toEqual(['POST', 'POST']))
      await uploader.stop()
      expect(methods).toEqual(['POST', 'POST', 'DELETE'])
    } finally { vi.useRealTimers() }
  })

  it('makes concurrent stop callers wait for generation invalidation', async () => {
    let finishDelete!: () => void
    let deleteStarted!: () => void
    const deleting = new Promise<void>(resolve => { finishDelete = resolve })
    const deleted = new Promise<void>(resolve => { deleteStarted = resolve })
    const request: ScreenPreviewRequest = async (_input, init) => {
      if (init.method === 'POST') return Response.json({ schema_version: 1, generation_id: generation })
      if (init.method === 'DELETE') {
        deleteStarted()
        await deleting
      }
      return new Response(null, { status: 204 })
    }
    const uploader = new LatestScreenPreviewUploader(request)
    await uploader.start(lease)
    let completed = 0
    const first = uploader.stop().then(() => { completed++ })
    await deleted
    const second = uploader.stop().then(() => { completed++ })
    await expect(Promise.race([
      second.then(() => true),
      new Promise<boolean>(resolve => setTimeout(() => resolve(false), 10)),
    ])).resolves.toBe(false)
    expect(completed).toBe(0)
    finishDelete()
    await Promise.all([first, second])
    expect(completed).toBe(2)
  })
})
