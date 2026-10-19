import { createApp, h, ref } from 'vue'
import { createPinia } from 'pinia'
import AdminPanel from '../../src/admin/panel/AdminPanel.vue'
import AudioSettings from '../../src/voice/AudioSettings.vue'
import { browserSupportsTouchPtt } from '../../src/voice/touch_ptt'
import ProfileSettings from '../../src/identity/ProfileSettings.vue'
import { describeAudioProcessing } from '../../src/voice/audio_processing_diagnostics'
import { bindMicrophoneAccount, microphoneMeter, microphoneSettingsError } from '../../src/voice/microphone_processing/runtime'
import type { AudioProcessingOptions } from '../../src/voice/livekit_gateway'
import type { OwnProfile } from '../../src/identity/profile_client'
import type { AdminSection } from '../../src/admin/panel/admin_section'
import type { VoiceShortcutBinding } from '../../src/voice/voice_shortcut'
import '../../src/style.css'
const params = new URLSearchParams(location.search), surface = params.get('surface') ?? 'audio'
document.documentElement.style.fontSize = params.get('scale') === '200' ? '200%' : '100%'
const id = '11111111-1111-4111-8111-111111111111'
bindMicrophoneAccount(id)
const categories = [{ id: 'category', name: 'Общее', position: 0, channels: [{ id, name: 'Общий чат', kind: 'TEXT' as const, position: 0, admissionClosed: false }] }]
const section = ref((params.get('section') ?? 'guild') as AdminSection)
const activation = ref<'VAD'|'PTT'>('VAD'), ptt = ref<string|null>(null)
const processing = ref<AudioProcessingOptions>({ autoGainControl: false, echoCancellation: true, noiseSuppressionMode: 'browser' })
const microphoneShortcut = ref<VoiceShortcutBinding|null>(null), deafenShortcut = ref<VoiceShortcutBinding|null>(null)
const hasAvatar = params.get('avatar') === '1'
const profile = ref<OwnProfile>({ account_id: id, login: hasAvatar ? 'pistol121' : 'fixture', display_name: hasAvatar ? 'Pistol121' : 'Тестовый участник', role: 'ADMINISTRATOR', avatar_url: hasAvatar ? '/profile-avatar-fixture.svg' : null })
function audio() {
  const diagnostics = describeAudioProcessing(processing.value)
  if(params.get('phase') === 'processing-error') diagnostics.noiseSuppressionRuntime.status = 'error'
  return h(AudioSettings, {
    activationError: null, activationMode: activation.value, processingDiagnostics: diagnostics,
    devices: { inputs: [{ id: 'default', label: 'Системный микрофон' }], outputs: [{ id: 'default', label: 'Системный динамик' }] },
    error: null, state: 'READY', connected: false, pttKey: ptt.value, touchPttEnabled: params.get('touchPtt') === '1' || browserSupportsTouchPtt(), processing: processing.value,
    microphoneShortcut: microphoneShortcut.value, deafenShortcut: deafenShortcut.value,
    onSetActivation: value => { activation.value=value }, onSetPttKey: value => { ptt.value=value },
    onSetProcessing: value => { processing.value=value },
    onSetShortcut: (action, value) => { (action==='microphone' ? microphoneShortcut : deafenShortcut).value=value },
    onResetShortcuts: () => { microphoneShortcut.value=null;deafenShortcut.value=null }, resetAudioVolumes: async () => {},
  })
}
createApp({ render: () => h('main', { class: `workspace-main-panel workspace-main-panel--${surface}`, style: 'min-height:100vh;min-width:0' }, [
  surface === 'admin' ? h(AdminPanel, { accountId:id, categories, revision:1, section:section.value, 'onUpdate:section': value => { section.value=value } })
    : surface === 'profile' ? h(ProfileSettings, { profile:profile.value, loading:false, loadError:null, onSaved:value => { profile.value=value } }) : audio(),
]) }).use(createPinia()).mount('#app')
Object.assign(window, { settingsFixture: { microphoneFailure() { microphoneMeter.value = { ...microphoneMeter.value, clipping:true }; microphoneSettingsError.value = 'Не удалось сохранить настройки микрофона.' } } })
