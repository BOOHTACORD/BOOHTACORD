import { createPinia, setActivePinia } from 'pinia'
import { createSSRApp } from 'vue'
import { renderToString } from 'vue/server-renderer'
import { describe, expect, it } from 'vitest'

import { useAuthorDirectory } from '../identity/author_directory'
import TextHistoryList from './TextHistoryList.vue'
import { useMessageStore } from './message_store'

describe('TEXT history reading order', () => {
  it('places older messages before newer ones and the pagination control above history', async () => {
    const pinia = createPinia()
    setActivePinia(pinia)
    useAuthorDirectory().acceptOwnProfile({ account_id: 'author', login: 'author', display_name: 'Автор', role: 'MEMBER' })
    const store = useMessageStore()
    store.messages = [2, 1].map((number) => ({
      id: `message-${number}`, channelId: 'text-1', authorId: 'author', clientMessageId: `client-${number}`,
      body: number === 1 ? 'Первое сообщение' : 'Второе сообщение', revision: 1,
      createdAt: `2026-09-25T10:00:0${number}Z`, deleted: false, attachments: [], mentionUserIds: [],
    }))
    store.nextCursor = 'older-cursor'
    store.historyLoaded = true
    const app = createSSRApp(TextHistoryList, { channelId: 'text-1', session: null })
    app.use(pinia)
    const html = await renderToString(app)

    expect(html.indexOf('Показать предыдущие сообщения')).toBeLessThan(html.indexOf('Первое сообщение'))
    expect(html.indexOf('Первое сообщение')).toBeLessThan(html.indexOf('Второе сообщение'))
  })

  it('shows one local-date divider per day before its messages', async () => {
    const pinia = createPinia()
    setActivePinia(pinia)
    const store = useMessageStore()
    store.messages = [{ id: '20', day: 20 }, { id: '19-b', day: 19 }, { id: '19-a', day: 19 }, { id: '18', day: 18 }].map(({ id, day }) => ({
      id: `message-${id}`, channelId: 'text-1', authorId: 'author', clientMessageId: `client-${id}`,
      body: `День ${day}`, revision: 1, createdAt: new Date(2026, 8, day, 12).toISOString(),
      deleted: false, attachments: [], mentionUserIds: [],
    }))
    const app = createSSRApp(TextHistoryList, { channelId: 'text-1', session: null })
    app.use(pinia)
    const html = await renderToString(app)

    expect(html).toContain('19 сентября 2026')
    expect(html.match(/<time datetime="2026-09-19">19 сентября 2026<\/time>/g)).toHaveLength(1)
    expect(html.indexOf('18 сентября 2026')).toBeLessThan(html.indexOf('День 18'))
    expect(html.indexOf('19 сентября 2026')).toBeLessThan(html.indexOf('День 19'))
    expect(html.indexOf('20 сентября 2026')).toBeLessThan(html.indexOf('День 20'))
  })
})
