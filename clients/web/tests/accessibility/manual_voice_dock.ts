import { createApp, h, reactive, ref } from 'vue'
import '../../src/style.css'
import VoiceDock from '../../src/voice/VoiceDock.vue'
import WorkspaceUserFooter from '../../src/workspace/WorkspaceUserFooter.vue'

const state = reactive({
  channel: { id: 'qa-voice', name: 'Тестовая комната', kind: 'VOICE' as const, position: 0, admissionClosed: false },
  activeSession: true,
  error: null as string | null,
  activationMode: 'VAD' as const,
  deafened: false,
  deafenChanging: false,
  microphoneMuted: false,
  microphonePermissionDenied: false,
  screenShareState: 'IDLE' as const,
  connectionQuality: 'UNKNOWN' as const,
  pingMs: null as number | null,
  state: 'CONNECTED' as 'CONNECTED' | 'LEAVING',
})
const settingsOpened = ref(false)

createApp({
  render: () => h('main', [
    h('aside', { class: 'sidebar is-open manual-voice-review', 'aria-label': 'Проверка кнопок голосового дока' }, [
      h(VoiceDock, {
        ...state,
        class: 'mobile-voice-dock',
        onToggleMicrophone: () => { state.microphoneMuted = !state.microphoneMuted },
        onToggleDeafen: () => { state.deafened = !state.deafened },
        onStartScreen: () => { state.screenShareState = 'STARTING' },
        onLeave: () => { state.state = 'LEAVING' },
      }),
      h(WorkspaceUserFooter, {
        role: 'ADMINISTRATOR',
        displayName: 'QA reviewer',
        onOpenSettings: () => { settingsOpened.value = true },
      }),
    ]),
    h('p', { class: 'manual-voice-review-note', role: 'status', 'aria-live': 'polite' }, settingsOpened.value ? 'Настройки аудио открыты' : 'Фокусируйтесь клавишей Tab или Option+Tab; активируйте кнопки клавишей Enter или Space.'),
  ]),
}).mount('#mount')
