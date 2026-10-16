import { describe, expect, it, vi } from 'vitest'

import { createMentionInboxController } from './mention_inbox_controller'
import type { MentionInboxItem, MentionInboxPage } from './mentions_inbox_client'
import { MessageRequestError } from '../conversation/message_client'

const item = (id: string): MentionInboxItem => ({ kind: 'CHANNEL', messageId: id, conversationId: 'channel-1', authorId: 'author-1', createdAt: '2026-10-08T10:00:00Z' })

describe('mention inbox paging', () => {
  it.each([401, 403, 404])('discards prior mentions and the cursor after access status %i on paging', async status => {
    const load = vi.fn<() => Promise<MentionInboxPage>>()
      .mockResolvedValueOnce({ mentions: [item('first')], nextCursor: 'cursor-1' })
      .mockRejectedValueOnce(new MessageRequestError(status))
    const inbox = createMentionInboxController(load)
    await inbox.refresh(); await inbox.loadMore()
    expect(inbox.mentions.value).toEqual([])
    expect(inbox.nextCursor.value).toBe('')
    expect(inbox.error.value).not.toBe('')
  })
  it('keeps a loaded page and cursor on a transient paging error so it can be retried', async () => {
    const load = vi.fn<() => Promise<MentionInboxPage>>()
      .mockResolvedValueOnce({ mentions: [item('first')], nextCursor: 'cursor-1' })
      .mockRejectedValueOnce(new MessageRequestError(503))
      .mockResolvedValueOnce({ mentions: [item('second')] })
    const inbox = createMentionInboxController(load)
    await inbox.refresh(); await inbox.loadMore()
    expect(inbox.mentions.value.map(row => row.messageId)).toEqual(['first'])
    expect(inbox.nextCursor.value).toBe('cursor-1')
    await inbox.loadMore()
    expect(inbox.mentions.value.map(row => row.messageId)).toEqual(['first', 'second'])
  })
  it('refreshes newest-first and deduplicates items across cursor pages', async () => {
    const load = vi.fn<() => Promise<MentionInboxPage>>()
      .mockResolvedValueOnce({ mentions: [item('first')], nextCursor: 'cursor-1' })
      .mockResolvedValueOnce({ mentions: [item('first'), item('second')] })
    const inbox = createMentionInboxController(load)
    await inbox.refresh()
    await inbox.loadMore()
    expect(load).toHaveBeenNthCalledWith(2, 'cursor-1')
    expect(inbox.mentions.value.map(({ messageId }) => messageId)).toEqual(['first', 'second'])
    expect(inbox.nextCursor.value).toBe('')
  })

  it('ignores a pending page from the previous conversation panel generation', async () => {
    let finish!: (page: MentionInboxPage) => void
    const load = vi.fn<() => Promise<MentionInboxPage>>()
      .mockImplementationOnce(() => new Promise((resolve) => { finish = resolve }))
      .mockResolvedValueOnce({ mentions: [item('newest')] })
    const inbox = createMentionInboxController(load)
    const old = inbox.refresh()
    await inbox.refresh()
    finish({ mentions: [item('stale')] })
    await old
    expect(inbox.mentions.value.map(({ messageId }) => messageId)).toEqual(['newest'])
  })
})
