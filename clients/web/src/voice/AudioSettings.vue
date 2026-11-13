<script setup lang="ts">
import AudioVolumeReset from './participant_volume/Reset.vue'
import type { AudioDevice, AudioDeviceKind } from './audio_devices'
import type { AudioSettingsState } from './audio_settings_store'
import type { VoiceActivationMode } from './activation_store'
import type { VoiceShortcutAction, VoiceShortcutBinding } from './voice_shortcut'
import ShortcutSettings from './activation/ShortcutSettings.vue'
import type { AudioProcessingDiagnostics } from './audio_processing_diagnostics'
import { capturePttAssignment } from './ptt_key_capture'
import type { AudioProcessingOptions } from './livekit_gateway'
import SensitivityControl from './microphone_processing/SensitivityControl.vue'
import AudioDeviceCheck from './AudioDeviceCheck.vue'
import AudioProcessingSettings from './AudioProcessingSettings.vue'
import { useAudioDeviceSelection } from './audio_device_selection'
import ProcessingDetails from './ProcessingDetails.vue'
import { microphoneMeter } from './microphone_processing/runtime'
import VoiceAudioDiagnostics from './audio_diagnostics/Diagnostics.vue'
import type { VoiceAudioDiagnostics as AudioSnapshot } from './audio_diagnostics/model'
import { onBeforeUnmount, onMounted, ref } from 'vue'

const props = defineProps<{
  activationError: string | null
  activationMode: VoiceActivationMode
  processingDiagnostics: AudioProcessingDiagnostics
  devices: { inputs: AudioDevice[]; outputs: AudioDevice[] }
  error: string | null
  pttKey: string | null
  touchPttEnabled?: boolean
  microphoneShortcut?: VoiceShortcutBinding | null
  deafenShortcut?: VoiceShortcutBinding | null
  processing: AudioProcessingOptions
  state: AudioSettingsState
  connected: boolean
  actualAudioDiagnostics?: AudioSnapshot | null
  resetAudioVolumes?: () => Promise<void>; volumeWarning?: string | null
  audioProfileLocked?: boolean
  microphoneTrack?: MediaStreamTrack
  inputDeviceId?: string
  inputWarning?: string | null
  inputSwitching?: boolean
}>()

const emit = defineEmits<{
  load: []
  select: [kind: AudioDeviceKind, deviceId: string]
  setActivation: [mode: VoiceActivationMode]
  setProcessing: [processing: AudioProcessingOptions]
  setPttKey: [key: string]
  resetShortcuts: []; setShortcut: [action: VoiceShortcutAction, binding: VoiceShortcutBinding | null]
}>()
const recordingPttKey = ref(false)
const windowsAudioGuidance = typeof navigator !== 'undefined' && /Windows/i.test(navigator.userAgent)
const entry = ref<HTMLElement | null>(null)
const { selectedInput, selectedOutput, selectedInputLabel, selectedOutputLabel, deviceWarning, choose } =
  useAudioDeviceSelection(props, (kind, id) => emit('select', kind, id))
let focusFrame: number | null = null
function refreshDevices(): void { emit('load') }
onMounted(() => { focusFrame = window.requestAnimationFrame(() => entry.value?.focus()); refreshDevices() })
onBeforeUnmount(() => { if (focusFrame !== null) window.cancelAnimationFrame(focusFrame) })
function capturePttKey(event: KeyboardEvent): void {
  if (!recordingPttKey.value) return
  capturePttAssignment(event, () => { recordingPttKey.value = false }, (code) => emit('setPttKey', code))
}

</script>

<template>
  <section ref="entry" class="audio-settings" aria-label="Настройки аудио" tabindex="-1">
    <header class="audio-settings-heading"><h1>Настройки аудио</h1></header>
    <p v-if="error" class="state state-error" role="alert">{{ error }}</p><p v-if="deviceWarning" class="state state-error" role="status">{{ deviceWarning }}</p>
    <div class="audio-settings-panel">
      <section class="audio-device-section"><header><h2>Устройства</h2><button class="audio-device-refresh gc-button gc-button--ghost" type="button" :disabled="state === 'LOADING'" @click="emit('load')">{{ state === 'LOADING' ? 'Ищем устройства…' : 'Обновить устройства' }}</button></header>
        <template v-if="state === 'READY'">
          <label>Микрофон<select class="gc-field" :value="selectedInput" :title="selectedInputLabel" :disabled="inputSwitching" @change="choose('audioinput', $event)"><option v-if="!devices.inputs.some(device => device.id === 'default')" value="default">Системный микрофон</option><option v-if="selectedInput !== 'default' && !devices.inputs.some(device => device.id === selectedInput)" :value="selectedInput" disabled>Выбранный микрофон недоступен</option><option v-for="device in devices.inputs" :key="device.id" :value="device.id">{{ device.label }}</option></select></label>
          <p v-if="inputSwitching" role="status">Переключаем микрофон…</p><p v-else-if="inputWarning" class="state state-error" role="status">{{ inputWarning }}</p>
          <label>Наушники или динамики<select class="gc-field" :value="selectedOutput" :title="selectedOutputLabel" @change="choose('audiooutput', $event)"><option v-for="device in devices.outputs" :key="device.id" :value="device.id">{{ device.label }}</option></select></label>
          <AudioDeviceCheck :input-id="selectedInput" :output-id="selectedOutput" :processing="processing" :connected="connected" :microphone-track="microphoneTrack" />
        </template>
        <details v-if="windowsAudioGuidance" class="audio-check-details">
          <summary>Музыка становится тише при подключении к голосовому каналу?</summary>
          <p>Windows может автоматически приглушать другие приложения во время голосовой связи. Откройте «Панель управления → Звук → Связь» и выберите «Действие не требуется». Браузер не может изменить эту системную настройку.</p>
        </details>
      </section>
      <section class="audio-activation-section"><header><h2>Активация микрофона</h2></header>
        <div class="audio-activation-selector" role="group" aria-label="Активация микрофона"><button type="button" :aria-pressed="activationMode === 'VAD'" @click="emit('setActivation', 'VAD')">По голосу</button><button type="button" :aria-pressed="activationMode === 'PTT'" @click="emit('setActivation', 'PTT')">По нажатию</button></div>
        <SensitivityControl :vad="activationMode === 'VAD'" />
        <button v-if="activationMode === 'PTT' && !touchPttEnabled" class="audio-ptt-button gc-button gc-button--secondary" type="button" @click="recordingPttKey = true" @keydown="capturePttKey">{{ recordingPttKey ? 'Нажмите клавишу…' : pttKey ? `PTT: ${pttKey}` : 'Назначить PTT-клавишу' }}</button>
        <p v-if="activationMode === 'PTT'" class="audio-ptt-guidance">{{ touchPttEnabled ? 'Удерживайте кнопку микрофона в панели голосового канала, чтобы говорить.' : pttKey ? 'Удерживайте назначенную клавишу, чтобы говорить.' : 'Назначьте клавишу, чтобы говорить.' }}</p>
        <p v-if="activationError" class="state state-error" role="alert">{{ activationError }}</p>
      </section>
      <p v-if="microphoneMeter.clipping" class="state-error" role="status">Перегрузка: уменьшите громкость микрофона.</p>
      <p v-if="volumeWarning" class="state-error" role="status">{{ volumeWarning }}</p>
      <section class="audio-shortcuts-section">
        <header><h2>Быстрые клавиши</h2><p>Микрофон и выключение звука</p></header>
        <ShortcutSettings :microphone-shortcut="microphoneShortcut" :deafen-shortcut="deafenShortcut" @reset-shortcuts="emit('resetShortcuts')" @set-shortcut="(action, binding) => emit('setShortcut', action, binding)" />
      </section>
      <AudioProcessingSettings :processing="processing" :diagnostics="processingDiagnostics" @set-processing="emit('setProcessing', $event)" />
      <section v-if="resetAudioVolumes" class="audio-playback-section">
        <h2>Воспроизведение</h2>
        <p>Громкость участников и демонстраций на этом устройстве.</p>
        <AudioVolumeReset :reset="resetAudioVolumes" />
      </section>
      <details class="audio-advanced"><summary><span>Диагностика</span><small>Технические сведения об обработке и голосовом подключении</small></summary>
      <div class="audio-advanced-content">
      <ProcessingDetails :diagnostics="processingDiagnostics" />
      <VoiceAudioDiagnostics :connected="connected || audioProfileLocked === true" :diagnostics="actualAudioDiagnostics" />
      </div></details>
    </div>
  </section>
</template>
