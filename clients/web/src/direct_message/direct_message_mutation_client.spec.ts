import { describe, expect, it, vi } from 'vitest'

import { createDirectMessage, deleteDirectMessage, editDirectMessage } from './direct_message_mutation_client'

describe('direct-message mutation client', () => {
  it('allows an empty body only when sending an attachment-only DM', async () => {
    const request = vi.fn().mockResolvedValue(new Response(JSON.stringify({
      id: 'message-image', direct_message_id: 'dm-1', author_id: 'user-1', client_message_id: 'client-image',
      body: '', revision: 1, created_at: '2026-09-18T10:00:00Z', mention_user_ids: [],
      attachments: [{ id: 'attachment-image', original_name: 'clipboard.png', byte_size: 4 }],
    })))

    await expect(createDirectMessage('dm-1', 'client-image', '', request, undefined, [], ['attachment-image']))
      .resolves.toMatchObject({ body: '', attachments: [{ id: 'attachment-image' }] })
    await expect(createDirectMessage('dm-1', 'client-empty', '', request)).rejects.toThrow('некорректное')
    expect(request).toHaveBeenCalledOnce()
    expect(request.mock.calls[0]?.[1].headers).toMatchObject({'X-Boohtacord-Support-Publication':'v1'})
    expect(JSON.parse(String(request.mock.calls[0]?.[1].body))).toMatchObject({ body: '', attachment_ids: ['attachment-image'] })
  })

  it('uses idempotent send, guarded edit and author-delete endpoints', async () => {
    const request = vi.fn()
      .mockResolvedValueOnce(new Response(JSON.stringify({ id: 'message-1', direct_message_id: 'dm-1', author_id: 'user-1', client_message_id: 'client-1', body: 'Привет', revision: 1, created_at: '2026-09-18T10:00:00Z', reply_to_id: 'message-0', mention_user_ids: [] })))
      .mockResolvedValueOnce(new Response(JSON.stringify({ id: 'message-1', direct_message_id: 'dm-1', author_id: 'user-1', client_message_id: 'client-1', body: 'Исправлено', revision: 2, created_at: '2026-09-18T10:00:00Z', edited_at: '2026-09-18T10:01:00Z', mention_user_ids: [] })))
      .mockResolvedValueOnce(new Response(null, { status: 204 }))

    await expect(createDirectMessage('dm-1', 'client-1', 'Привет', request, 'message-0')).resolves.toMatchObject({ deleted: false, replyToId: 'message-0' })
    await expect(editDirectMessage('dm-1', 'message-1', 'Исправлено', 1, request)).resolves.toMatchObject({ revision: 2, editedAt: '2026-09-18T10:01:00Z' })
    await expect(deleteDirectMessage('dm-1', 'message-1', request)).resolves.toBeUndefined()
    expect(request).toHaveBeenNthCalledWith(1, '/api/v1/direct-messages/dm-1/messages', expect.objectContaining({ method: 'POST', credentials: 'same-origin', body: '{"client_message_id":"client-1","body":"Привет","reply_to_id":"message-0"}' }))
    expect(request).toHaveBeenNthCalledWith(2, '/api/v1/direct-messages/dm-1/messages/message-1', expect.objectContaining({ method: 'PATCH', body: '{"body":"Исправлено","expected_revision":1}' }))
    expect(request).toHaveBeenNthCalledWith(3, '/api/v1/direct-messages/dm-1/messages/message-1', expect.objectContaining({ method: 'DELETE' }))
  })
})
