import { createPinia, setActivePinia } from 'pinia'
import { beforeEach, describe, expect, it } from 'vitest'

import { useMessageStore } from './message_store'

function message(id: number, channelId = 'text-1') {
  return { id: `message-${id}`, channel_id: channelId, author_id: 'user-1', client_message_id: `client-${id}`, body: `Текст ${id}`, revision: 1, created_at: `2026-09-17T12:00:${String(id).padStart(2, '0')}Z`, attachments: [], mention_user_ids: [] }
}

function page(messages: ReturnType<typeof message>[], nextCursor?: string): Response {
  return new Response(JSON.stringify({ messages, ...(nextCursor ? { next_cursor: nextCursor } : {}) }))
}

describe('TEXT history pagination', () => {
  beforeEach(() => setActivePinia(createPinia()))

  it('uses the oldest cursor, deduplicates overlaps and stops after the last page', async () => {
    const store = useMessageStore()
    const urls: string[] = []
    const request = async (url: string) => {
      urls.push(url)
      return url.includes('before=') ? page([message(2), message(1)], undefined) : page([message(3), message(2)], 'message-2')
    }

    await store.open('text-1', request)
    expect(store.nextCursor).toBe('message-2')
    await expect(store.loadOlder(request)).resolves.toBe(true)
    expect(urls[1]).toContain('before=message-2')
    expect(store.messages.map(({ id }) => id)).toEqual(['message-3', 'message-2', 'message-1'])
    expect(store.nextCursor).toBeUndefined()
    await expect(store.loadOlder(request)).resolves.toBe(false)
    expect(urls).toHaveLength(2)
  })

  it('retains the loaded page and cursor on error, then retries the same cursor', async () => {
    const store = useMessageStore()
    const urls: string[] = []
    let fail = true
    const request = async (url: string) => {
      urls.push(url)
      if (!url.includes('before=')) return page([message(3), message(2)], 'message-2')
      if (fail) { fail = false; throw new Error('Сеть недоступна') }
      return page([message(1)])
    }

    await store.open('text-1', request)
    await expect(store.loadOlder(request)).resolves.toBe(false)
    expect(store.messages.map(({ id }) => id)).toEqual(['message-3', 'message-2'])
    expect(store.nextCursor).toBe('message-2')
    expect(store.olderError).toBe('Сеть недоступна')
    await expect(store.loadOlder(request)).resolves.toBe(true)
    expect(urls.slice(1)).toEqual([urls[1], urls[1]])
    expect(store.olderError).toBeNull()
    expect(store.messages.map(({ id }) => id)).toEqual(['message-3', 'message-2', 'message-1'])
  })

  it('keeps older pages and their cursor during realtime refresh', async () => {
    const store = useMessageStore()
    let latest = [message(4), message(3)]
    const request = async (url: string) => url.includes('before=')
      ? page([message(2)], 'message-2')
      : page(latest, 'message-3')

    await store.open('text-1', request)
    await store.loadOlder(request)
    latest = [message(5), message(4)]
    await store.refresh(request)
    expect(store.messages.map(({ id }) => id)).toEqual(['message-5', 'message-4', 'message-3', 'message-2'])
    expect(store.nextCursor).toBe('message-2')
  })

  it('opens around a searched message and keeps paging in both directions', async () => {
    const store = useMessageStore(), urls: string[] = []
    const request = async (url: string) => {
      urls.push(url)
      const parsed = new URL(url, 'https://example.test')
      if (parsed.searchParams.has('at')) return page([message(10), message(9)], 'message-9')
      if (parsed.searchParams.has('after')) return page([message(11), message(12)], 'message-12')
      return page([message(20), message(19)], 'message-19')
    }

    await store.open('text-1', request)
    await expect(store.openAround('message-10', request)).resolves.toBe(true)
    expect(urls[1]).toContain('at=message-10')
    expect(store.messages.map(({ id }) => id)).toEqual(['message-10', 'message-9'])
    expect(store.nextCursor).toBe('message-9')
    await expect(store.loadNewer(request)).resolves.toBe(true)
    expect(urls[2]).toContain('after=message-10')
    expect(store.messages.map(({ id }) => id)).toContain('message-12')
  })

  it('ignores an old-page response after switching channels', async () => {
    const store = useMessageStore()
    let resolveOlder: ((response: Response) => void) | undefined
    const request = async (url: string) => {
      if (url.includes('before=')) return new Promise<Response>((resolve) => { resolveOlder = resolve })
      if (url.includes('text-2')) return page([message(8, 'text-2')])
      return page([message(3)], 'message-3')
    }

    await store.open('text-1', request)
    const older = store.loadOlder(request)
    await store.open('text-2', request)
    resolveOlder?.(page([message(1)]))
    await expect(older).resolves.toBe(false)
    expect(store.messages.map(({ id }) => id)).toEqual(['message-8'])
    expect(store.channelId).toBe('text-2')
    expect(store.olderLoading).toBe(false)
  })

})
