import { createApp, h, ref } from 'vue'
import { createPinia } from 'pinia'
import AdminPanel from '../../src/admin/panel/AdminPanel.vue'
import AudioSettings from '../../src/voice/AudioSettings.vue'
import ProfileSettings from '../../src/identity/ProfileSettings.vue'
import SearchPanel from '../../src/search/SearchPanel.vue'
import VoicePrejoin from '../../src/voice/VoicePrejoin.vue'
import VoiceDock from '../../src/voice/VoiceDock.vue'
import ScreenShareSetupDialog from '../../src/voice/ScreenShareSetupDialog.vue'
import TextConversation from '../../src/conversation/TextConversation.vue'
import DirectMessageConversation from '../../src/direct_message/DirectMessageConversation.vue'
import QuickJumpPanel from '../../src/search/QuickJumpPanel.vue'
import ArchivePanel from '../../src/channel/readonly_archive/ArchivePanel.vue'
import ConversationFilesPanel from '../../src/conversation/files_panel/ConversationFilesPanel.vue'
import PersonalMentionsPanel from '../../src/search/PersonalMentionsPanel.vue'
import { describeAudioProcessing } from '../../src/voice/audio_processing_diagnostics'
import { disconnectNotice } from '../../src/voice/disconnect_notice/model'
import type { AdminSection } from '../../src/admin/panel/admin_section'
import '../../src/style.css'

const params = new URLSearchParams(location.search), surface = params.get('surface') ?? 'prejoin'
const phase = params.get('phase') ?? 'idle'
document.documentElement.style.fontSize = params.get('scale') === '200' ? '200%' : '100%'
const id = '11111111-1111-4111-8111-111111111111'
const channel = { id, name: 'Общий чат', kind: 'TEXT' as const, position: 0, admissionClosed: false }
const categories = [{ id: 'category', name: 'Общее', position: 0, channels: [channel] }]
const section = ref((params.get('section') ?? 'guild') as AdminSection), result = ref('')
const processing = ref({ autoGainControl: false, echoCancellation: true, noiseSuppressionMode: 'browser' as const })
const opened = ref(true)
const microphoneMuted = ref(false)
const profile = { account_id: id, login: 'fixture', display_name: 'Тестовый участник', role: 'ADMINISTRATOR' as const, avatar_url: null }
const components = () => {
  if (surface === 'admin') return h(AdminPanel, { accountId: id, categories, revision: 1, section: section.value, 'onUpdate:section': value => { section.value = value } })
  if (surface === 'profile') return h(ProfileSettings, { profile, loading: false, loadError: null })
  if (surface === 'audio') return h(AudioSettings, {
    activationError: null, activationMode: 'VAD', processingDiagnostics: describeAudioProcessing(processing.value),
    devices: { inputs: [{ id: 'default', label: 'Системный микрофон' }], outputs: [{ id: 'default', label: 'Системный динамик' }] },
    error: phase === 'error' ? 'Нет доступа к микрофону.' : null, state: 'READY', connected: false, pttKey: null, processing: processing.value,
    onSetProcessing: value => { processing.value = value }, resetAudioVolumes: async () => { result.value = 'reset' },
  })
  if (surface === 'prejoin') return h(VoicePrejoin, { channelId: id, voiceState: phase === 'joining' ? 'JOINING' : 'IDLE', voiceError: null, voiceTransferRequired: false,
    roster: { channelId: id, revision: 1, participants: [] }, notice: phase === 'revoked' ? disconnectNotice('CHANNEL_CLOSED', 'server') : null,
    onJoin: (_id, _transfer, mode) => { result.value = mode === 'listener' ? 'listener' : 'join' },
  })
  if (surface === 'dock') return h(VoiceDock, { channel: { ...channel, kind: 'VOICE' }, activeSession: true, error: null, activationMode: 'VAD', deafened: false, deafenChanging: false, microphoneMuted: microphoneMuted.value, microphonePermissionDenied: phase === 'denied', state: 'CONNECTED', onToggleMicrophone: () => { microphoneMuted.value = !microphoneMuted.value }, onLeave: () => { result.value = 'leave' } })
  if (surface === 'share') return opened.value ? h(ScreenShareSetupDialog, { initialProfile: 'P1080_60', onCancel: () => { opened.value = false }, onStart: () => { result.value = 'start' } }) : null
  if (surface === 'chat') return h(TextConversation, { accountId: id, active: true, channelId: id, channelName: channel.name, navOpen: false, membersOpen: false, showMembers: true })
  if (surface === 'dm') return h(DirectMessageConversation, { accountId: id, active: true, directMessageId: 'dm-fixture', otherParticipantId: 'peer', otherParticipantDisplayName: 'Собеседник', navOpen: false })
  if (surface === 'search') return h(SearchPanel, { currentConversation: { id, kind: 'CHANNEL', label: channel.name }, channelLabels: { [id]: channel.name }, directMessageLabels: {}, onClose: () => { result.value = 'close' } })
  if (surface === 'quick') return h(QuickJumpPanel, { channels: [{ ...channel, categoryName: 'Общее' }], people: [], status: '', hasMore: true, onNext: () => { result.value = 'next' } })
  if (surface === 'archive') return h(ArchivePanel)
  if (surface === 'files') return h(ConversationFilesPanel, { kind: 'CHANNEL', conversationId: id })
  return h(PersonalMentionsPanel, { channelLabels: { [id]: channel.name }, directMessageLabels: {} })
}
createApp({ render: () => h('main', {
  class: surface === 'audio' ? 'workspace-main-panel workspace-main-panel--audio' : surface === 'admin' ? 'workspace-main-panel workspace-main-panel--admin' : surface === 'profile' ? 'workspace-main-panel workspace-main-panel--profile' : '',
  style: ['chat', 'dm'].includes(surface) ? 'height:100vh' : 'min-height:100vh;min-width:0',
}, [components(), h('output', { 'data-testid': 'result', class: 'gc-sr-only' }, result.value)]) }).use(createPinia()).mount('#app')
