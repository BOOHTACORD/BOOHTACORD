import { describe, expect, it, vi } from 'vitest'

import { uploadTextAttachment } from './text_attachment_upload_client'

describe('text attachment upload client', () => {
  it('uploads one file through the authenticated same-origin endpoint', async () => {
    const file = new File(['note'], 'notes.txt', { type: 'text/plain' })
    const request = vi.fn().mockResolvedValue(new Response(JSON.stringify({
      id: 'attachment-1', original_name: 'notes.txt', byte_size: 4,
    }), { status: 201 }))

    await expect(uploadTextAttachment('text-1', file, request)).resolves.toEqual({
      id: 'attachment-1', originalName: 'notes.txt', sizeBytes: 4,
    })
    expect(request).toHaveBeenCalledWith(
      '/api/v1/channels/text-1/attachments',
      expect.objectContaining({ method: 'POST', credentials: 'same-origin' }),
    )
    const form = request.mock.calls[0]?.[1]?.body as FormData
    expect(form.get('file')).toMatchObject({ name: 'notes.txt', size: 4 })
  })

  it('rejects malformed private upload metadata', async () => {
    const file = new File(['note'], 'notes.txt', { type: 'text/plain' })
    const request = vi.fn().mockResolvedValue(new Response(JSON.stringify({
      id: 'attachment-1', original_name: 'notes.txt', byte_size: '4',
    }), { status: 201 }))

    await expect(uploadTextAttachment('text-1', file, request)).rejects.toThrow('некорректные данные')
  })

  it('rejects images above the shared 25 MB limit before sending bytes', async () => {
    const request = vi.fn()
    const oversized = { name: 'clipboard.png', size: 25_000_001 } as File
    await expect(uploadTextAttachment('text-1', oversized, request)).rejects.toThrow('ограничению')
    expect(request).not.toHaveBeenCalled()
  })

  it('accepts an image exactly at the inclusive25MB boundary', async () => {
    const file = new File([new Uint8Array(25_000_000)], 'maximum.png', { type: 'image/png' })
    const request = vi.fn().mockResolvedValue(new Response(JSON.stringify({
      id: 'maximum', original_name: file.name, byte_size: file.size,
    }), { status: 201 }))
    await expect(uploadTextAttachment('text-1', file, request)).resolves.toMatchObject({ sizeBytes: 25_000_000 })
    expect(request).toHaveBeenCalledOnce()
    expect((request.mock.calls[0]?.[1]?.body as FormData).get('file')).toMatchObject({ size: 25_000_000 })
  })
})
