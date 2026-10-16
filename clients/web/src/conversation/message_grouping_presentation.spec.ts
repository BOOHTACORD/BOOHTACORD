import { createPinia, setActivePinia } from 'pinia'
import { createSSRApp } from 'vue'
import { renderToString } from 'vue/server-renderer'
import { describe, expect, it } from 'vitest'

import DirectMessageHistoryList from '../direct_message/DirectMessageHistoryList.vue'
import { useDirectMessageStore } from '../direct_message/direct_message_store'
import { useAuthorDirectory } from '../identity/author_directory'
import TextHistoryList from './TextHistoryList.vue'
import { useMessageStore } from './message_store'

const common = (id: string, minute: number) => ({ id, authorId: 'author', clientMessageId: id,
  body: id, createdAt: `2026-09-25T10:0${minute}:00Z`, revision: 1, deleted: false, attachments: [], mentionUserIds: [] })

describe('compact continuation presentation', () => {
  it('renders one avatar and one visible author for two grouped TEXT and DM messages', async () => {
    const pinia = createPinia()
    setActivePinia(pinia)
    useAuthorDirectory().acceptOwnProfile({ account_id: 'author', login: 'author', display_name: 'Алекс', role: 'MEMBER' })
    const textStore = useMessageStore()
    textStore.channelId = 'text-1'
    textStore.messages = [common('m2', 2), common('m1', 1)].map((message) => ({ ...message, channelId: 'text-1' }))
    textStore.historyLoaded = true
    const textApp = createSSRApp(TextHistoryList, { channelId: 'text-1', session: null })
    textApp.use(pinia)
    const text = await renderToString(textApp)
    const dmStore = useDirectMessageStore()
    dmStore.directMessageId = 'dm-1'
    dmStore.messages = [common('d2', 2), common('d1', 1)].map((message) => ({ ...message, directMessageId: 'dm-1' }))
    dmStore.historyLoaded = true
    const dmApp = createSSRApp(DirectMessageHistoryList, { directMessageId: 'dm-1', session: null,
      otherParticipantId: 'author', otherParticipantDisplayName: 'Алекс' })
    dmApp.use(pinia)
    const dm = await renderToString(dmApp)

    for (const html of [text, dm]) {
      expect((html.match(/class="message-avatar"/g) ?? [])).toHaveLength(1)
      expect((html.match(/class="message-author"/g) ?? [])).toHaveLength(1)
      expect(html).toContain('message-row grouped')
      expect(html).toContain('История')
      expect((html.match(/<time class="message-time" datetime=/g) ?? [])).toHaveLength(2)
      expect(html).toMatch(/message-avatar-spacer[^>]*><time[^>]*aria-label="[^"]*2026/)
      expect(html).not.toContain('message-avatar-spacer" aria-hidden')
    }
  })
})
