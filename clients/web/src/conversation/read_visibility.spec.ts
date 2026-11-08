import { describe, expect, it, vi } from 'vitest'

import { advanceReadIfVisible } from '../direct_message/direct_message_read_gate'
import { advanceTextReadIfVisible } from './text_read_gate'
import { firstUnreadIsVisible, newestVisibleServerMessageId, shouldAdvanceVisibleRead } from './read_visibility'

function viewport(rows: { id: string; top: number; bottom: number }[], height = 100): HTMLElement {
  return {
    clientHeight: height,
    getBoundingClientRect: () => ({ top: 0, bottom: height }),
    querySelectorAll: () => rows.map(({ id, top, bottom }) => ({
      dataset: { messageId: id }, getBoundingClientRect: () => ({ top, bottom }),
    })),
  } as unknown as HTMLElement
}

describe('read visibility in a scrolled conversation', () => {
  const messages = [{ id: 'newest' }, { id: 'middle' }, { id: 'oldest' }]

  it('selects the newest actually intersecting server row for TEXT and DM', async () => {
    const list = viewport([
      { id: 'oldest', top: 5, bottom: 40 },
      { id: 'middle', top: 40, bottom: 90 },
      { id: 'newest', top: 120, bottom: 165 },
    ])
    const visible = newestVisibleServerMessageId(list, messages)
    expect(visible).toBe('middle')
    const textAdvance = vi.fn().mockResolvedValue(undefined)
    const dmAdvance = vi.fn().mockResolvedValue(undefined)
    await advanceTextReadIfVisible({ activeChannelId: 'text-1', renderedChannelId: 'text-1', newestDisplayedMessageId: visible, visibilityState: 'visible' }, textAdvance)
    await advanceReadIfVisible({ activeDirectMessageId: 'dm-1', renderedDirectMessageId: 'dm-1', newestDisplayedMessageId: visible, visibilityState: 'visible' }, dmAdvance)
    expect(textAdvance).toHaveBeenCalledWith('text-1', 'middle')
    expect(dmAdvance).toHaveBeenCalledWith('dm-1', 'middle')
  })

  it('ignores optimistic rows and never advances an invisible or zero-height list', () => {
    const rows = [{ id: 'pending', top: 80, bottom: 110 }, { id: 'server', top: 40, bottom: 80 }]
    const history = [{ id: 'pending', sendStatus: 'sending' as const }, { id: 'server' }]
    expect(newestVisibleServerMessageId(viewport(rows), history)).toBe('server')
    expect(newestVisibleServerMessageId(viewport([{ id: 'server', top: 100, bottom: 140 }]), history)).toBeUndefined()
    expect(newestVisibleServerMessageId(viewport(rows, 0), history)).toBeUndefined()
    expect(newestVisibleServerMessageId(null, history)).toBeUndefined()
  })

  it('waits for the first unread row to enter the viewport before advancing', () => {
    const list = viewport([{ id: 'latest', top: 10, bottom: 50 }])
    expect(firstUnreadIsVisible(list, 'unread')).toBe(false)
    expect(firstUnreadIsVisible(viewport([
      { id: 'unread', top: 95, bottom: 120 },
      { id: 'latest', top: 10, bottom: 50 },
    ]), 'unread')).toBe(true)
    expect(firstUnreadIsVisible(list, undefined)).toBe(true)
  })

  it('does not regress a cursor when scrolling back through older rows', () => {
    expect(shouldAdvanceVisibleRead(messages, 'text-1:newest', 'text-1', 'middle')).toBe(false)
    expect(shouldAdvanceVisibleRead(messages, 'text-1:middle', 'text-1', 'newest')).toBe(true)
    expect(shouldAdvanceVisibleRead(messages, 'dm-1:newest', 'text-1', 'middle')).toBe(true)
  })
})
