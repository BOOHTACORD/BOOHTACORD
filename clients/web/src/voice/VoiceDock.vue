<script setup lang="ts">
import type { VoiceDisconnectNotice } from './disconnect_notice/model'
import { computed } from 'vue'
import type { TopologyChannel } from '../channel/topology_client'
import type { ScreenShareState, VoiceConnectionState } from './connection_store'
import type { VoiceActivationMode } from './activation_store'
import { streamStartNotice } from './stream_start_runtime'
import { screenCaptureSupported, screenCaptureUnavailableMessage } from './screen_capture_support'
import { voiceConnectionQualityLabel, type VoiceConnectionQuality } from './voice_connection_quality'

const props = withDefaults(defineProps<{
  channel: TopologyChannel | null
  activeSession: boolean
  error: string | null
  notice?: VoiceDisconnectNotice | null
  activationMode: VoiceActivationMode
  deafened: boolean
  deafenChanging: boolean
  microphoneMuted: boolean
  microphonePermissionDenied: boolean
  screenShareState?: ScreenShareState
  connectionQuality?: VoiceConnectionQuality
  pingMs?: number | null
  participantCount?: number
  state: VoiceConnectionState
}>(), { screenShareState: 'IDLE', connectionQuality: 'UNKNOWN', pingMs: null })
const emit = defineEmits<{ leave: []; startScreen: []; stopScreen: []; toggleDeafen: []; toggleMicrophone: [] }>()
const screenCaptureAvailable = screenCaptureSupported()
const captureUnavailableMessage = screenCaptureUnavailableMessage()
const connected = computed(() => (props.channel !== null || props.activeSession) && (props.state === 'CONNECTED' || props.state === 'LISTENER'))
const screenShareBusy = computed(() => props.screenShareState === 'STARTING' || props.screenShareState === 'STOPPING')
const connectionQualityLabel = computed(() => voiceConnectionQualityLabel(props.connectionQuality))
const connectionPingLabel = computed(() => props.pingMs === null ? '—' : `${props.pingMs} мс`)
const connectionQualityDescription = computed(() => `Качество соединения: ${connectionQualityLabel.value} · ping ${connectionPingLabel.value}`)
const microphoneButtonLabel = computed(() => props.activationMode === 'PTT'
  ? 'Микрофон управляется push-to-talk'
  : props.microphonePermissionDenied
    ? 'Повторить доступ к микрофону'
    : props.microphoneMuted ? 'Включить микрофон' : 'Выключить микрофон')
const microphonePermissionMessage = computed(() => props.activationMode === 'PTT'
  ? 'Вы подключены как слушатель: браузер запретил доступ к микрофону. Разрешите микрофон в настройках сайта, затем удерживайте клавишу push-to-talk.'
  : 'Вы подключены как слушатель: браузер запретил доступ к микрофону. Разрешите его в настройках сайта, затем нажмите «Повторить доступ к микрофону».')
const status = computed(() => {
  if (props.state === 'JOINING') return 'Подключаемся к голосовому каналу'
  if (props.state === 'RECONNECTING') return 'Восстанавливаем голосовое соединение'
  if (props.state === 'LEAVING') return 'Завершаем голосовое подключение'
  if (props.channel) return connected.value ? 'Голос подключён' : 'В голосовом канале'
  return props.activeSession ? 'Голос подключён · канал не отображается' : 'Голос не подключён'
})
</script>

<template>
  <section class="voice-dock" :class="{ connected, 'mobile-visible': Boolean(channel || activeSession || state !== 'IDLE') }" aria-label="Состояние голосового подключения" data-testid="voice-dock">
    <div class="voice-dock-header">
      <svg v-if="connected" class="voice-dock-headset" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M3 14v-3a9 9 0 0 1 18 0v3"/><rect x="3" y="12" width="4" height="9" rx="2"/><rect x="17" y="12" width="4" height="9" rx="2"/></svg>
      <span class="status-dot" :class="{ connected }" aria-hidden="true"></span>
      <div class="voice-dock-copy"><p class="voice-status" role="status" aria-atomic="true">{{ status }}</p><p v-if="channel && connected" class="voice-dock-subtitle">{{ channel.name }}<template v-if="participantCount"> · {{ participantCount }} {{ participantCount === 1 ? 'участник' : participantCount < 5 ? 'участника' : 'участников' }}</template></p></div>
      <span v-if="connected" class="voice-quality" :class="[`voice-quality--${connectionQuality.toLowerCase()}`, { 'voice-quality--unmeasured': pingMs === null }]" role="img" :aria-label="connectionQualityDescription" :title="connectionQualityDescription">
        <svg class="voice-quality-icon" viewBox="0 0 20 20" aria-hidden="true"><path d="M2 13h3v5H2zM7 9h3v9H7zM12 5h3v13h-3zM17 1h2v17h-2z" /></svg>
        <span>{{ connectionPingLabel }}</span>
      </span>
    </div>
    <p v-if="streamStartNotice && activeSession" class="voice-stream-alert-notice" role="status">В канале началась демонстрация экрана</p>
    <p v-if="notice" class="state state-error">{{ notice.message }}</p>
    <p v-else-if="error" class="state state-error" role="alert">{{ error }}</p>
    <p v-if="microphonePermissionDenied" class="voice-dock-mic-notice state" role="status">{{ microphonePermissionMessage }}</p>
    <div v-if="channel || activeSession" class="voice-actions">
      <button v-if="channel" class="voice-icon-button" :class="{ 'voice-icon-button--danger-active': microphoneMuted && !microphonePermissionDenied && activationMode !== 'PTT' }" type="button" :aria-label="microphoneButtonLabel" :aria-pressed="!microphoneMuted && !microphonePermissionDenied" :disabled="activationMode === 'PTT' || deafened" :title="microphoneButtonLabel" @click="emit('toggleMicrophone')"><svg class="voice-icon" viewBox="0 0 24 24" aria-hidden="true"><rect x="9" y="2" width="6" height="12" rx="3"/><path d="M5 10v2a7 7 0 0 0 14 0v-2M12 19v3M8 22h8"/></svg></button>
      <button v-if="channel" class="voice-icon-button" :class="{ 'voice-icon-button--danger-active': deafened }" type="button" :aria-label="deafened ? 'Включить удалённый звук' : 'Выключить удалённый звук'" :aria-pressed="deafened" :disabled="deafenChanging || state === 'LEAVING'" :title="deafened ? 'Включить удалённый звук' : 'Выключить удалённый звук'" @click="emit('toggleDeafen')"><svg class="voice-icon" viewBox="0 0 24 24" aria-hidden="true"><path d="M3 14v-3a9 9 0 0 1 18 0v3"/><rect x="3" y="12" width="4" height="9" rx="2"/><rect x="17" y="12" width="4" height="9" rx="2"/></svg></button>
      <button v-if="channel" class="voice-icon-button" type="button" :aria-label="screenShareState === 'SHARING' ? 'Остановить демонстрацию экрана' : screenCaptureAvailable ? 'Начать демонстрацию экрана' : captureUnavailableMessage" :aria-pressed="screenShareState === 'SHARING'" :disabled="screenShareBusy || state === 'JOINING' || state === 'RECONNECTING' || state === 'LEAVING' || (screenShareState !== 'SHARING' && !screenCaptureAvailable)" :title="screenShareState === 'SHARING' ? 'Остановить демонстрацию экрана' : screenCaptureAvailable ? 'Начать демонстрацию экрана' : captureUnavailableMessage" @click="screenShareState === 'SHARING' ? emit('stopScreen') : emit('startScreen')"><svg class="voice-icon" viewBox="0 0 24 24" aria-hidden="true"><path v-if="screenShareState === 'SHARING'" d="M4 4h16v12H4zM8 20h8M12 16v4M9 9l6 6m0-6-6 6" /><rect v-else x="2" y="3" width="20" height="14" rx="2"/><path v-if="screenShareState !== 'SHARING'" d="M8 21h8M12 17v4"/><path v-if="screenShareState !== 'SHARING'" d="m8 11 4-4 4 4M12 7v6"/></svg></button>
      <button class="voice-icon-button voice-icon-button--danger" type="button" aria-label="Выйти из голосового канала" :disabled="state === 'LEAVING'" :title="state === 'LEAVING' ? 'Выходим…' : 'Выйти из голосового канала'" @click="emit('leave')"><svg class="voice-icon voice-icon--filled" viewBox="0 0 24 24" aria-hidden="true"><path d="M12 9c-3.16 0-6.1.91-8.42 2.44-.37.2-.58.53-.58.9v2.26c0 .47.33.87.78.98l2.74.68c.48.12.99-.1 1.24-.53l1.2-2.01c1.99-.46 4.05-.46 6.04 0l1.2 2.01c.25.42.76.65 1.24.53l2.74-.68c.45-.11.78-.51.78-.98v-2.26c0-.37-.21-.7-.58-.9C18.1 9.91 15.16 9 12 9Z"/></svg></button>
    </div>
  </section>
</template>
