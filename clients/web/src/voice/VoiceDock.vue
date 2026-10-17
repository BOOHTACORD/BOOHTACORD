<script setup lang="ts">
import VoiceRoomControls from './VoiceRoomControls.vue'
import { voiceRoomSummary } from './voice_room_copy'
import type { VoiceDisconnectNotice } from './disconnect_notice/model'
import { computed } from 'vue'
import type { TopologyChannel } from '../channel/topology_client'
import type { ScreenShareState, VoiceConnectionState } from './connection_store'
import type { VoiceActivationMode } from './activation_store'
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
const connected = computed(() => (props.channel !== null || props.activeSession) && (props.state === 'CONNECTED' || props.state === 'LISTENER'))
const connectionQualityLabel = computed(() => voiceConnectionQualityLabel(props.connectionQuality))
const connectionPingLabel = computed(() => props.pingMs === null ? '—' : `${props.pingMs} мс`)
const connectionQualityDescription = computed(() => `Качество соединения: ${connectionQualityLabel.value} · ping ${connectionPingLabel.value}`)
const microphonePermissionMessage = computed(() => props.activationMode === 'PTT'
  ? 'Вы подключены как слушатель: браузер запретил доступ к микрофону. Разрешите микрофон в настройках сайта, затем удерживайте клавишу push-to-talk.'
  : 'Вы подключены как слушатель: браузер запретил доступ к микрофону. Разрешите его в настройках сайта, затем нажмите «Повторить доступ к микрофону».')
const status = computed(() => {
  if (props.state === 'JOINING') return 'Подключаемся к голосовому каналу'
  if (props.state === 'RECONNECTING') return 'Восстанавливаем голосовое соединение'
  if (props.state === 'LEAVING') return 'Завершаем голосовое подключение'
  if (props.state === 'ERROR') return 'Не удалось подключиться'
  if (props.channel) return connected.value ? 'Голос подключён' : 'Голос не подключён'
  return props.activeSession ? 'Голос подключён · канал не отображается' : 'Голос не подключён'
})
</script>

<template>
  <section class="voice-dock" :class="{ connected, 'mobile-visible': Boolean(channel || activeSession || state !== 'IDLE') }" aria-label="Состояние голосового подключения" data-testid="voice-dock">
    <div class="voice-dock-header">
      <svg v-if="connected" class="voice-dock-headset" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M3 14v-3a9 9 0 0 1 18 0v3"/><rect x="3" y="12" width="4" height="9" rx="2"/><rect x="17" y="12" width="4" height="9" rx="2"/></svg>
      <span class="status-dot" :class="{ connected }" aria-hidden="true"></span>
      <div class="voice-dock-copy"><p class="voice-status" role="status" aria-atomic="true">{{ status }}</p><p v-if="channel && connected" class="voice-dock-subtitle" :title="channel.name">{{ channel.name }}<template v-if="participantCount"> · {{ voiceRoomSummary(participantCount, 0) }}</template></p></div>

    </div>
    <p v-if="notice" class="state" :class="{ 'state-error': notice.reason !== 'VOLUNTARY_LEAVE' }">{{ notice.message }}</p>
    <p v-else-if="error" class="state state-error" role="alert">{{ error }}</p>
    <p v-if="microphonePermissionDenied" class="voice-dock-mic-notice state" role="status">{{ microphonePermissionMessage }}</p>
    <VoiceRoomControls v-if="channel || activeSession" dock :channel-available="Boolean(channel)" :voice-state="state" :screen-state="screenShareState" :activation-mode="activationMode" :microphone-muted="microphoneMuted" :microphone-permission-denied="microphonePermissionDenied" :deafened="deafened" :deafen-changing="deafenChanging" :toggle-microphone="() => emit('toggleMicrophone')" :toggle-deafen="() => emit('toggleDeafen')" @start-screen="emit('startScreen')" @stop-screen="emit('stopScreen')" @leave="emit('leave')" />
    <details v-if="connected" class="voice-connection-details">
      <summary class="voice-quality" :class="[`voice-quality--${connectionQuality.toLowerCase()}`, { 'voice-quality--unmeasured': pingMs === null }]" :aria-label="`Сведения о соединении. ${connectionQualityDescription}`" :title="connectionQualityDescription">
        <svg class="voice-quality-icon" viewBox="0 0 20 20" aria-hidden="true"><path d="M2 13h3v5H2zM7 9h3v9H7zM12 5h3v13h-3zM17 1h2v17h-2z" /></svg>
      </summary>
      <dl><div><dt>Соединение</dt><dd>{{ connectionQualityLabel }}</dd></div><div><dt>Ping</dt><dd>{{ connectionPingLabel }}</dd></div><div><dt>Микрофон</dt><dd>{{ activationMode === 'PTT' ? 'Нажми и говори' : 'Автоактивация голосом' }}</dd></div></dl>
    </details>
  </section>
</template>
