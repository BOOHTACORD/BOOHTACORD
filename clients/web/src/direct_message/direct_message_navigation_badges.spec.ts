import { createPinia } from 'pinia'
import { createSSRApp } from 'vue'
import { renderToString } from 'vue/server-renderer'
import { describe, expect, it } from 'vitest'
import { useAuthorDirectory } from '../identity/author_directory'

import DirectMessageNavigation from './DirectMessageNavigation.vue'

describe('DM navigation counters', () => {
  it('shows unread and mention counts separately with accessible labels', async () => {
    const app = createSSRApp(DirectMessageNavigation, {
      directMessages: [{ id: 'dm-1', otherParticipantId: 'user-2', otherParticipantDisplayName: 'Лера', createdAt: '2026-09-25T00:00:00Z', unreadCount: 4, mentionCount: 2 }],
      error: null, loading: false,
    })
    app.use(createPinia())
    const html = await renderToString(app)
    expect(html).toContain('aria-label="Непрочитанных личных сообщений: 4"')
    expect(html).toContain('aria-label="Упоминаний в личном диалоге: 2"')
  })

  it('shows the peer avatar from the protected member avatar route', async () => {
    const pinia = createPinia()
    useAuthorDirectory(pinia).acceptOwnProfile({ account_id: 'user-2', login: 'lera', display_name: 'Лера', role: 'MEMBER',
      avatar_url: '/api/v1/members/user-2/avatar', profile_revision: 3 })
    const app = createSSRApp(DirectMessageNavigation, {
      directMessages: [{ id: 'dm-1', otherParticipantId: 'user-2', otherParticipantDisplayName: 'Лера', createdAt: '2026-09-25T00:00:00Z', unreadCount: 0, mentionCount: 0 }],
      error: null, loading: false,
    })
    app.use(pinia)
    const html = await renderToString(app)
    expect(html).toContain('src="/api/v1/members/user-2/avatar?revision=3"')
    expect(html).not.toContain('>ЛЕ</span>')
  })
})
