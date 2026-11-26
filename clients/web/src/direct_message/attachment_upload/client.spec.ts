import { expect, it, vi } from 'vitest'
import { uploadDirectMessageAttachment } from './client'
import { createManagedUploadQueue } from '../../conversation/upload_queue/queue'
const message = 'Недостаточно места на сервере. Повторите загрузку, когда место освободится.'
const response = (status: number, body: unknown) => new Response(JSON.stringify(body), { status })

it('exposes structured storage status without changing its bounded legacy diagnostic', async () => {
  const request = vi.fn().mockResolvedValue(response(507, { error: { code: 'INSUFFICIENT_STORAGE' } }))
  await expect(uploadDirectMessageAttachment('dm-a', new File(['x'], 'a.png'), request)).rejects.toMatchObject({
    status: 507, code: 'INSUFFICIENT_STORAGE', message: 'Не удалось загрузить вложение (507: INSUFFICIENT_STORAGE).',
  })
})

it('keeps the same failed DM file blocked until an explicit storage retry succeeds', async () => {
  const file = new File(['image'], 'clipboard.png', { type: 'image/png' })
  const request = vi.fn().mockResolvedValueOnce(response(507, { error: { code: 'INSUFFICIENT_STORAGE' } }))
    .mockResolvedValueOnce(response(201, { id: 'prepared', original_name: file.name, byte_size: file.size }))
  const upload = vi.fn((id: string, file: File) => uploadDirectMessageAttachment(id, file, request))
  const queue = createManagedUploadQueue(() => 'dm-a', () => false, vi.fn(), upload)
  await queue.upload([file])
  expect(queue.error.value).toBe(message); expect(queue.items.value[0]?.error).toBe(message)
  expect(queue.failed.value).toEqual([file]); expect(queue.attachments.value).toEqual([])
  expect(queue.blocked.value).toBe(true); expect(request).toHaveBeenCalledOnce()
  await queue.retry()
  expect(upload.mock.calls[1]?.[1]).toBe(file)
  expect(queue.error.value).toBeNull(); expect(queue.blocked.value).toBe(false)
  expect(queue.attachments.value).toMatchObject([{ id: 'prepared' }])
})

it.each([[403, 'FORBIDDEN'], [413, 'TOO_LARGE']])('retains the diagnostic and typed status for %s', async (status, code) => {
  const request = vi.fn().mockResolvedValue(response(status, { error: { code } }))
  await expect(uploadDirectMessageAttachment('dm-a', new File(['x'], 'a'), request)).rejects.toThrow(`(${status}: ${code})`)
})

it('accepts exactly25MB and rejects oversize before transmission', async () => {
  const file = new File([new Uint8Array(25_000_000)], 'maximum.png', { type: 'image/png' })
  const request = vi.fn().mockResolvedValue(response(201, { id: 'maximum', original_name: file.name, byte_size: file.size }))
  await expect(uploadDirectMessageAttachment('dm-a', file, request)).resolves.toMatchObject({ sizeBytes: file.size })
  await expect(uploadDirectMessageAttachment('dm-a', { name: 'large', size: 25_000_001 } as File, request)).rejects.toThrow('ограничению')
  expect(request).toHaveBeenCalledOnce()
})
