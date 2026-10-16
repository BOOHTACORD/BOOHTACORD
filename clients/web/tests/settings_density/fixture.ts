import { createApp, h, ref } from 'vue'
import { createPinia } from 'pinia'
import AudioSettings from '../../src/voice/AudioSettings.vue'
import { describeAudioProcessing } from '../../src/voice/audio_processing_diagnostics'
import type { AudioProcessingOptions } from '../../src/voice/livekit_gateway'
import type { VoiceActivationMode } from '../../src/voice/activation_store'
import '../../src/style.css'

const phase = new URLSearchParams(location.search).get('phase')
const mode = ref<VoiceActivationMode>('VAD'), ptt = ref<string | null>(null)
const processing = ref<AudioProcessingOptions>({ autoGainControl: false, echoCancellation: true, noiseSuppressionMode: 'browser' })
const action = ref(''), loaded = ref(0)
createApp({ render: () => h('main', { class: 'workspace-main-panel workspace-main-panel--audio', style: 'height:100vh' }, [
  h(AudioSettings, {
    activationMode: mode.value, activationError: null, pttKey: ptt.value,
    processing: processing.value, processingDiagnostics: describeAudioProcessing(processing.value, undefined,
      phase === 'processing-error' ? { requestedMode: 'browser', effectiveMode: 'unknown', status: 'error', fallbackReason: 'processor-error' } : undefined),
    devices: { inputs: [{ id: 'default', label: 'Системный микрофон' }], outputs: [{ id: 'default', label: 'Системный динамик' }] },
    error: phase === 'denied' ? 'Нет доступа к микрофону.' : null,
    state: 'READY', connected: false,
    onLoad: () => { loaded.value++ }, onSelect: () => { action.value = 'device' },
    onSetActivation: value => { mode.value = value }, onSetPttKey: key => { ptt.value = key },
    onSetProcessing: value => { processing.value = value; action.value = 'processing' },
    resetAudioVolumes: async () => { action.value = 'reset' },
  }), h('output', { 'data-testid': 'action', class: 'gc-sr-only' }, action.value),
  h('output', { 'data-testid': 'loads', class: 'gc-sr-only' }, loaded.value),
]) }).use(createPinia()).mount('#app')
