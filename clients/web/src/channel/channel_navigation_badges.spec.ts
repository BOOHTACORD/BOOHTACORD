import { createSSRApp } from 'vue'
import { renderToString } from 'vue/server-renderer'
import { createPinia } from 'pinia'
import { describe, expect, it } from 'vitest'

import { useAuthorDirectory } from '../identity/author_directory'
import ChannelNavigation from './ChannelNavigation.vue'

describe('channel navigation counters', () => {
  it('renders a known avatar for a connected voice participant', async () => {
    const pinia = createPinia()
    useAuthorDirectory(pinia).acceptOwnProfile({ account_id: 'user-1', login: 'mika', display_name: 'Мика', role: 'MEMBER', avatar_url: '/avatar' })
    const html = await renderToString(createSSRApp(ChannelNavigation, {
      accountId: 'user-1',
      activeVoiceChannelId: 'voice-1', selectedChannelId: 'voice-1',
      voicePresence: { channelId: 'voice-1', memberCount: 1, members: [{ id: 'user-1', name: 'Мика', microphoneMuted: true, deafened: true, microphoneUnavailable: false, speaking: false, isSpeaking: false, screenSharing: false, self: false }] },
      topology: { revision: 1, categories: [{ id: 'cat-1', name: 'Игры', position: 0, channels: [
        { id: 'voice-1', name: 'Команда', kind: 'VOICE', position: 0, admissionClosed: false },
      ] }] },
    }).use(pinia))
    expect(html).toContain('<img src="/api/v1/members/user-1/avatar" alt=""')
    expect(html).toContain('aria-label="Не слышит участников"')
    expect(html).not.toContain('aria-label="Микрофон выключен"')
  })

  it('shows caller-local TEXT unread and mention badges without adding them to VOICE', async () => {
    const html = await renderToString(createSSRApp(ChannelNavigation, {
      accountId: 'user-1',
      activeVoiceChannelId: undefined, selectedChannelId: undefined, voicePresence: null,
      topology: { revision: 2, categories: [{ id: 'cat-1', name: 'Игры', position: 0, channels: [
        { id: 'text-1', name: 'Общий', kind: 'TEXT', position: 0, admissionClosed: false, unreadCount: 4, mentionCount: 2 },
        { id: 'voice-1', name: 'Команда', kind: 'VOICE', position: 1, admissionClosed: false },
      ] }] },
    }))
    expect(html).toContain('aria-label="Непрочитанных сообщений: 4"')
    expect(html).toContain('aria-label="Упоминаний: 2"')
    expect(html.match(/Упоминаний:/g)).toHaveLength(1)
  })

  it('uses the two-letter handoff initials for connected voice members without avatars', async () => {
    const html = await renderToString(createSSRApp(ChannelNavigation, {
      accountId: 'user-1',
      activeVoiceChannelId: 'voice-1', selectedChannelId: 'text-1',
      voicePresence: { channelId: 'voice-1', memberCount: 1, members: [{ id: 'user-2', name: 'Alex', microphoneMuted: false, microphoneUnavailable: false, speaking: false, isSpeaking: false, screenSharing: false, self: false }] },
      topology: { revision: 1, categories: [{ id: 'cat-1', name: 'ОБЩЕНИЕ', position: 0, channels: [
        { id: 'voice-1', name: 'Общий', kind: 'VOICE', position: 0, admissionClosed: false },
      ] }] },
    }))
    expect(html).toMatch(/class="voice-member-avatar"[^>]*>[\s\S]*?AL[\s\S]*?<\/span>/)
    expect(html).toContain('M15 8a6 6 0 0 1 0 8M18 5a10 10 0 0 1 0 14')
  })

  it('shows replicated deafen in a voice roster preview before joining', async () => {
    const html = await renderToString(createSSRApp(ChannelNavigation, {
      accountId: 'user-1',
      activeVoiceChannelId: undefined,
      selectedChannelId: 'voice-1',
      voicePresence: null,
      voiceRosters: [{ channelId: 'voice-1', participants: [{ accountId: 'user-2', displayName: 'Alex', screenSharing: false, microphoneMuted: true, deafened: true }] }],
      topology: { revision: 1, categories: [{ id: 'cat-1', name: 'ОБЩЕНИЕ', position: 0, channels: [
        { id: 'voice-1', name: 'Общий', kind: 'VOICE', position: 0, admissionClosed: false },
      ] }] },
    }).use(createPinia()))

    expect(html).toContain('aria-label="Не слышит участников"')
    expect(html).not.toContain('aria-label="Микрофон выключен"')
  })
})
