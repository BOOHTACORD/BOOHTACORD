import { expect, it, vi } from 'vitest'
import { createManagedUploadQueue } from './queue'

it('explains real insufficient storage while preserving the exact file for explicit retry', async () => {
  const file = new File(['image'], 'clipboard.png', { type: 'image/png' })
  const upload = vi.fn().mockRejectedValueOnce(Object.assign(new Error('request rejected'), {
    status: 507, code: 'INSUFFICIENT_STORAGE',
  })).mockResolvedValueOnce({ id: 'prepared', originalName: file.name, sizeBytes: file.size })
  const queue = createManagedUploadQueue(() => 'channel', () => false, vi.fn(), upload)
  await queue.upload([file])
  const message = 'Недостаточно места на сервере. Повторите загрузку, когда место освободится.'
  expect(queue.error.value).toBe(message)
  expect(queue.items.value[0]?.error).toBe(message)
  expect(queue.failed.value).toEqual([file])
  expect(queue.attachments.value).toEqual([])
  expect(queue.blocked.value).toBe(true)
  expect(upload).toHaveBeenCalledTimes(1)
  await queue.retry()
  expect(upload.mock.calls[1]?.[1]).toBe(file)
  expect(queue.blocked.value).toBe(false)
  expect(queue.error.value).toBeNull()
  expect(queue.attachments.value[0]?.id).toBe('prepared')
})

it.each([new Error('507: preserved legacy diagnostic'), { status: 507, code: 'OTHER' }, null])(
  'preserves the established fallback for an unrelated error %s', async cause => {
    const queue = createManagedUploadQueue(() => 'channel', () => false, vi.fn(), vi.fn().mockRejectedValue(cause))
    await queue.upload([new File(['x'], 'file.png')])
    expect(queue.error.value).toBe(cause instanceof Error ? cause.message : 'Не удалось загрузить вложение.')
    expect(queue.items.value[0]?.error).toBe(queue.error.value)
  },
)
