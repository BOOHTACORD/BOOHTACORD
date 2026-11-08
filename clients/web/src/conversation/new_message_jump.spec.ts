import { describe, expect, it } from 'vitest'

import { isHistoryNearBottom, newServerMessageCount, shouldFollowNewestMessages } from './new_message_jump'

describe('new-message jump while reading older history', () => {
  const messages = [{ id: 'new-2' }, { id: 'new-1' }, { id: 'seen' }, { id: 'older' }]

  it('counts only new server rows after a loaded newest ID', () => {
    expect(newServerMessageCount(messages, 'seen', true)).toBe(2)
    expect(newServerMessageCount(messages, 'new-2', true)).toBe(0)
    expect(newServerMessageCount([...messages, { id: 'older-2' }], 'new-2', true)).toBe(0)
    expect(newServerMessageCount(messages, 'missing', true)).toBe(0)
  })

  it('does not count initial history or optimistic sends, but counts a new message after an empty loaded history', () => {
    const pending = [{ id: 'pending', sendStatus: 'sending' as const }, { id: 'seen' }]
    expect(newServerMessageCount(messages, undefined, false)).toBe(0)
    expect(newServerMessageCount(pending, 'seen', true)).toBe(0)
    expect(newServerMessageCount([{ id: 'first' }], undefined, true)).toBe(1)
  })

  it('does not follow a replaced history window as if it were new messages', () => {
    expect(shouldFollowNewestMessages([{ id: 'old-20' }, { id: 'old-19' }], 'latest-before-search', true, true)).toBe(false)
    expect(shouldFollowNewestMessages([{ id: 'new-2' }, { id: 'new-1' }, { id: 'seen' }], 'seen', true, true)).toBe(true)
    expect(shouldFollowNewestMessages([{ id: 'new-2' }, { id: 'seen' }], 'seen', true, false)).toBe(false)
  })

  it('treats only a near-bottom viewport as following latest', () => {
    expect(isHistoryNearBottom({ scrollHeight: 500, clientHeight: 200, scrollTop: 200 })).toBe(false)
    expect(isHistoryNearBottom({ scrollHeight: 500, clientHeight: 200, scrollTop: 205 })).toBe(true)
    expect(isHistoryNearBottom(null)).toBe(false)
  })
})
