import { createPinia, setActivePinia } from 'pinia'
import { beforeEach, describe, expect, it } from 'vitest'

import { useDirectMessageStore } from './direct_message_store'

function message(id: number, directMessageId = 'dm-1') {
  return { id: `message-${id}`, direct_message_id: directMessageId, author_id: 'user-2', client_message_id: `client-${id}`, body: `Текст ${id}`, revision: 1, deleted: false, created_at: new Date(Date.UTC(2026, 8, 18, 10, 0, id)).toISOString(), mention_user_ids: [] }
}

function page(messages: ReturnType<typeof message>[], nextCursor?: string): Response {
  return new Response(JSON.stringify({ messages, ...(nextCursor ? { next_cursor: nextCursor } : {}) }))
}

describe('DM history pagination', () => {
  beforeEach(() => setActivePinia(createPinia()))

  it('loads older messages with before, deduplicates overlap and stops at the end', async () => {
    const store = useDirectMessageStore()
    const urls: string[] = []
    const request = async (url: string) => {
      urls.push(url)
      return url.includes('before=') ? page([message(2), message(1)]) : page([message(3), message(2)], 'message-2')
    }

    await store.open('dm-1', request)
    await expect(store.loadOlder(request)).resolves.toBe(true)
    expect(urls[1]).toContain('before=message-2')
    expect(store.messages.map(({ id }) => id)).toEqual(['message-3', 'message-2', 'message-1'])
    expect(store.nextCursor).toBeUndefined()
    await expect(store.loadOlder(request)).resolves.toBe(false)
    expect(urls).toHaveLength(2)
  })

  it('keeps the cursor and messages on an older-page error, then retries', async () => {
    const store = useDirectMessageStore()
    const urls: string[] = []
    let fail = true
    const request = async (url: string) => {
      urls.push(url)
      if (!url.includes('before=')) return page([message(3), message(2)], 'message-2')
      if (fail) { fail = false; throw new Error('Сеть недоступна') }
      return page([message(1)])
    }

    await store.open('dm-1', request)
    await expect(store.loadOlder(request)).resolves.toBe(false)
    expect(store.nextCursor).toBe('message-2')
    expect(store.olderError).toBe('Сеть недоступна')
    expect(store.messages.map(({ id }) => id)).toEqual(['message-3', 'message-2'])
    await expect(store.loadOlder(request)).resolves.toBe(true)
    expect(urls.slice(1)).toEqual([urls[1], urls[1]])
    expect(store.olderError).toBeNull()
    expect(store.messages.map(({ id }) => id)).toEqual(['message-3', 'message-2', 'message-1'])
  })

  it('ignores a delayed older page after selecting another DM', async () => {
    const store = useDirectMessageStore()
    let resolveOlder: ((response: Response) => void) | undefined
    const request = async (url: string) => {
      if (url.includes('before=')) return new Promise<Response>((resolve) => { resolveOlder = resolve })
      return url.includes('dm-2') ? page([message(8, 'dm-2')]) : page([message(3)], 'message-3')
    }

    await store.open('dm-1', request)
    const older = store.loadOlder(request)
    await store.open('dm-2', request)
    resolveOlder?.(page([message(1)]))
    await expect(older).resolves.toBe(false)
    expect(store.directMessageId).toBe('dm-2')
    expect(store.messages.map(({ id }) => id)).toEqual(['message-8'])
    expect(store.olderLoading).toBe(false)
  })

  it('preserves old pages and the oldest cursor after realtime refresh', async () => {
    const store = useDirectMessageStore()
    let latest = [message(4), message(3)]
    const request = async (url: string) => url.includes('before=') ? page([message(2)], 'message-2') : page(latest, 'message-3')

    await store.open('dm-1', request)
    await store.loadOlder(request)
    latest = [message(5), message(4)]
    await store.refreshHistory(request)
    expect(store.messages.map(({ id }) => id)).toEqual(['message-5', 'message-4', 'message-3', 'message-2'])
    expect(store.nextCursor).toBe('message-2')
  })

  it('opens around a searched message and pages toward newer messages', async () => {
    const store = useDirectMessageStore(), urls: string[] = []
    const request = async (url: string) => {
      urls.push(url)
      const parsed = new URL(url, 'https://example.test')
      if (parsed.searchParams.has('at')) return page([message(10), message(9)], 'message-9')
      if (parsed.searchParams.has('after')) return page([message(11), message(12)], 'message-12')
      return page([message(20), message(19)], 'message-19')
    }

    await store.open('dm-1', request)
    await expect(store.openAround('message-10', request)).resolves.toBe(true)
    expect(urls[1]).toContain('at=message-10')
    expect(store.messages.map(({ id }) => id)).toEqual(['message-10', 'message-9'])
    expect(store.nextCursor).toBe('message-9')
    await expect(store.loadNewer(request)).resolves.toBe(true)
    expect(urls[2]).toContain('after=message-10')
    expect(store.messages.map(({ id }) => id)).toContain('message-12')
  })
})
