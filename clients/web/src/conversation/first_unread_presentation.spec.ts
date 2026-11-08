import { createPinia } from 'pinia'
import { createSSRApp } from 'vue'
import { renderToString } from 'vue/server-renderer'
import { describe, expect, it, vi } from 'vitest'
import { useTopologyStore } from '../channel/topology_store'
import { useDirectMessageStore } from '../direct_message/direct_message_store'
import DirectMessageConversation from '../direct_message/DirectMessageConversation.vue'
import TextConversation from './TextConversation.vue'

vi.stubGlobal('fetch', vi.fn().mockResolvedValue(new Response(JSON.stringify({ messages: [] }))))

describe('first unread navigation', () => {
  it('does not interrupt the TEXT conversation with an unread navigation banner', async () => {
    const pinia = createPinia()
    useTopologyStore(pinia).topology = { revision: 1, categories: [{ id: 'cat', name: 'Игры', position: 0, channels: [
      { id: 'text-1', name: 'Общий', kind: 'TEXT', position: 0, admissionClosed: false, unreadCount: 2, mentionCount: 0, firstUnreadMessageId: 'message-1' },
    ] }] }
    const app = createSSRApp(TextConversation, { accountId: 'account', active: true, channelId: 'text-1', channelName: 'Общий', navOpen: false, membersOpen: false, showMembers: false })
    app.use(pinia)
    const html = await renderToString(app)
    expect(html).not.toContain('Есть непрочитанные сообщения.')
    expect(html).not.toContain('К первому непрочитанному')
    expect(html).not.toContain('Остаться у последних')
  })

  it('does not interrupt a caller DM with an unread navigation banner', async () => {
    const pinia = createPinia()
    useDirectMessageStore(pinia).directMessages = [{ id: 'dm-1', otherParticipantId: 'peer', otherParticipantDisplayName: 'Лера', createdAt: '2026-09-01T00:00:00Z', unreadCount: 1, mentionCount: 0, firstUnreadMessageId: 'message-1' }]
    const app = createSSRApp(DirectMessageConversation, { accountId: 'account', active: true, directMessageId: 'dm-1', otherParticipantId: 'peer', otherParticipantDisplayName: 'Лера', navOpen: false })
    app.use(pinia)
    const html = await renderToString(app)
    expect(html).not.toContain('Есть непрочитанные сообщения.')
    expect(html).not.toContain('К первому непрочитанному')
  })
})
