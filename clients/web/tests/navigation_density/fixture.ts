import { createApp, h, ref } from 'vue'
import { createPinia } from 'pinia'
import ChannelNavigation from '../../src/channel/ChannelNavigation.vue'
import DirectMessageNavigation from '../../src/direct_message/DirectMessageNavigation.vue'
import WorkspaceSidebarTabs from '../../src/workspace/WorkspaceSidebarTabs.vue'
import WorkspaceUserFooter from '../../src/workspace/WorkspaceUserFooter.vue'
import VoiceDock from '../../src/voice/VoiceDock.vue'
import type { ChannelTopology } from '../../src/channel/topology_client'
import '../../src/style.css'

// Actual production components in the production sidebar structure. Synthetic
// input state is explicit; authenticated workspace journeys are a separate gate.
export const longName = 'Обсуждение очень длинного названия канала для совместной работы'
const params = new URLSearchParams(location.search)
const accountId = 'navigation-fixture'
const categories: ChannelTopology['categories'] = Array.from({ length: 3 }, (_, category) => ({
  id: `category-${category}`, name: `${category + 1}. Длинное название раздела для совместной работы`, position: category,
  channels: Array.from({ length: 12 }, (_, index) => ({ id: `channel-${category}-${index}`, name: index === 0 ? `${longName} ${category}` : `Канал ${category + 1}.${index + 1}`, kind: index === 1 ? 'VOICE' : 'TEXT', position: index,
    admissionClosed: index === 2, unreadCount: index === 0 ? 120 : 0, mentionCount: index === 0 ? 3 : 0 })),
}))
const permissions = Object.fromEntries(['category.create','category.delete','channel.text.create','channel.text.delete','channel.voice.create','channel.voice.delete'].map(key => [key, params.get('member') !== '1']))
const active = ref<'channels'|'messages'>('channels'), selected = ref('channel-0-0'), selectedDM = ref('dm-0'), result = ref(''), open = ref(true)
const participants = Array.from({ length: 10 }, (_, n) => ({ accountId: `voice-${n}`, displayName: `Длинное имя голосового участника ${n}`, microphoneMuted: n % 2 === 0, screenSharing: n === 0 }))
const rosters = [{ channelId: 'channel-0-1', revision: 1, participants }]
const dms = Array.from({ length: 32 }, (_, n) => ({ id: `dm-${n}`, otherParticipantId: `peer-${n}`, otherParticipantDisplayName: n === 0 ? longName : `Собеседник ${n}`, createdAt: '2026-10-16T00:00:00Z', unreadCount: n === 0 ? 120 : 0, mentionCount: n === 0 ? 3 : 0 }))
createApp({ setup() { return () => h('div', { class: 'app-frame' }, [h('div', { class: 'gc-shell no-aside' }, [
  h('aside', { class: ['sidebar', { 'is-open': open.value }], 'aria-label': 'Навигация гильдии' }, [
    h('button', { class: 'guild-header', type: 'button' }, [h('span', { class: 'guild-header-copy', id: 'app-title' }, 'Тестовая гильдия')]),
    h('div', { class: 'nav-drawer' }, [
      h(WorkspaceSidebarTabs, { class: 'sidebar-tabs', active: active.value, onSelect: value => { active.value = value } }),
      h('div', { class: 'nav-content', tabindex: 0, 'aria-label': 'Список бесед' }, [active.value === 'channels'
        ? h(ChannelNavigation, { accountId, selectedChannelId: selected.value, activeVoiceChannelId: 'channel-1-1', topology: { revision: 1, categories }, voiceRosters: rosters, voicePresence: { channelId: 'channel-1-1', memberCount: 1, members: [{ id: 'self', name: 'Вы', microphoneMuted: false, microphoneUnavailable: false, speaking: true, isSpeaking: true, screenSharing: false, self: true }] }, permissions,
          onSelect: channel => { selected.value = channel.id; result.value = channel.id }, onDeleteChannel: channel => { result.value = `action:${channel.id}` }, onCreateInCategory: category => { result.value = `create:${category.id}` } })
        : h(DirectMessageNavigation, { directMessages: dms, error: null, loading: false, selectedDirectMessageId: selectedDM.value, onSelect: id => { selectedDM.value = id; result.value = id } })]),
    ]),
    h(VoiceDock, { class: 'mobile-voice-dock mobile-visible', channel: { ...categories[1]!.channels[1]! }, activeSession: true, activationMode: 'VAD', state: 'CONNECTED', microphoneMuted: false, microphonePermissionDenied: false, deafened: false, deafenChanging: false, error: null, onLeave: () => { result.value = 'leave' } }),
    h(WorkspaceUserFooter, { role: 'ADMINISTRATOR', accountID: accountId, displayName: 'Тестовый профиль', online: true }),
  ]), h('main', { class: 'main', id: 'main-region' }, [h('h1', 'Тест навигации'), h('button', { onClick: () => { open.value = !open.value } }, 'Навигация'), h('output', { 'data-testid': 'result' }, result.value)]),
])]) } }).use(createPinia()).mount('#app')
