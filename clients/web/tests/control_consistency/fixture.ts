import { createApp, h, ref } from 'vue'
import { createPinia } from 'pinia'
import AdminGuildSettings from '../../src/admin/guild_settings/AdminGuildSettings.vue'
import AudioSettings from '../../src/voice/AudioSettings.vue'
import ArchivePanel from '../../src/channel/readonly_archive/ArchivePanel.vue'
import QuickJumpPanel from '../../src/search/QuickJumpPanel.vue'
import ConversationFilesPanel from '../../src/conversation/files_panel/ConversationFilesPanel.vue'
import { describeAudioProcessing } from '../../src/voice/audio_processing_diagnostics'
import '../../src/style.css'

const params = new URLSearchParams(location.search)
document.documentElement.style.fontSize = params.get('scale') === '200' ? '200%' : '100%'
const surface = params.get('surface') ?? 'guild'
const channel = { id: '11111111-1111-4111-8111-111111111111', name: 'Общий чат', kind: 'TEXT' as const, position: 0, admissionClosed: false }
const action = ref(''), processing = ref({ autoGainControl: false, echoCancellation: true, noiseSuppressionMode: 'browser' as const })
const changed = (value: string) => { action.value = value }
const variants = ['primary', 'secondary', 'ghost', 'danger']
createApp({ render: () => h('main', {
  'data-controls-fixture': surface,
  class: surface === 'audio' ? 'workspace-main-panel workspace-main-panel--audio' : '',
  style: surface === 'audio' ? 'min-height:100vh' : 'width:min(100%,580px);margin:0 auto;padding:16px;min-width:0',
}, [
  surface === 'guild' ? h(AdminGuildSettings, { categories: [{ id: 'category', name: 'Общее', position: 0, channels: [channel] }] }) : null,
  surface === 'audio' ? h(AudioSettings, {
    activationError: null, activationMode: 'VAD', processingDiagnostics: describeAudioProcessing(processing.value),
    devices: { inputs: [{ id: 'default', label: 'Системный микрофон' }], outputs: [{ id: 'default', label: 'Системный динамик' }] },
    error: null, state: 'READY', connected: false, pttKey: null, processing: processing.value,
    onSetProcessing: value => { processing.value = value; changed('processing') },
    onResetShortcuts: () => changed('shortcuts'),
    resetAudioVolumes: async () => { changed('reset'); await new Promise(resolve => setTimeout(resolve, 400)) },
  }) : null,
  surface === 'archive' ? h(ArchivePanel) : null,
  surface === 'quick' ? h(QuickJumpPanel, {
    channels: [{ ...channel, categoryName: 'Общее' }], people: [], status: '', hasMore: true,
    onNext: () => changed('next'), onSelect: () => changed('select'),
  }) : null,
  surface === 'files' ? h(ConversationFilesPanel, { kind: 'CHANNEL', conversationId: channel.id,
    onClose: () => changed('close'), onOpenMessage: () => changed('open') }) : null,
  surface === 'variants' ? h('section', { 'aria-label': 'Варианты действий' }, [
    ...variants.map(variant => h('button', { type: 'button', class: `gc-button gc-button--${variant}`, onClick: () => changed(variant) }, variant)),
    h('button', { type: 'button', class: 'gc-button gc-button--secondary', disabled: true, onClick: () => changed('disabled') }, 'Недоступно'),
    h('button', { type: 'button', class: 'gc-button', disabled: true, 'aria-busy': true }, 'Сохраняем…'),
    h('button', { type: 'button', class: 'gc-button gc-button--ghost gc-button--icon', 'aria-label': 'Закрыть пример', title: 'Закрыть пример', onClick: () => changed('icon') }, h('span', { 'aria-hidden': true }, '×')),
  ]) : null,
  h('output', { 'data-testid': 'action', style: 'display:block;margin:16px' }, action.value),
]) }).use(createPinia()).mount('#app')
