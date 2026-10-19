<script setup lang="ts">
import { computed } from 'vue'
import { vActionHint } from '../shared/action_hint/directive'
import type { VoiceActivationMode } from './activation_store'
import type { VoiceConnectionState, ScreenShareState } from './connection_store'
import type { ScreenProfile } from './livekit_gateway'
import { screenCaptureSupported, screenCaptureUnavailableMessage } from './screen_capture_support'
import TouchPttButton from './TouchPttButton.vue'

const props = withDefaults(defineProps<{ voiceState: VoiceConnectionState; screenState: ScreenShareState; selectedScreenProfile?: ScreenProfile; microphoneMuted: boolean; deafened: boolean; microphonePermissionDenied?: boolean; activationMode?: VoiceActivationMode; touchPttEnabled?: boolean; setTouchPttPressed?: (pressed: boolean) => void; deafenChanging?: boolean; channelAvailable?: boolean; dock?: boolean; toggleMicrophone: () => void; toggleDeafen: () => void }>(), { selectedScreenProfile: 'P1080_30', activationMode: 'VAD', touchPttEnabled: false, setTouchPttPressed: () => undefined, microphonePermissionDenied: false, deafenChanging: false, channelAvailable: true, dock: false })
const emit = defineEmits<{ startScreen: [profile: ScreenProfile]; stopScreen: []; leave: [] }>()
const captureAvailable = screenCaptureSupported()
const captureMessage = screenCaptureUnavailableMessage()
const transitioning = computed(() => ['JOINING', 'LEAVING', 'IDLE', 'ERROR'].includes(props.voiceState))
const microphoneLabel = computed(() => props.activationMode === 'PTT' ? 'Микрофон управляется push-to-talk' : props.microphonePermissionDenied ? 'Повторить доступ к микрофону' : props.microphoneMuted || props.deafened ? 'Включить микрофон' : 'Выключить микрофон')
const microphoneState = computed(() => props.microphonePermissionDenied ? 'denied' : props.activationMode === 'PTT' ? 'ptt' : props.microphoneMuted || props.deafened ? 'muted' : 'enabled')
const deafenLabel = computed(() => props.deafened ? 'Включить удалённый звук' : 'Выключить удалённый звук')
const screenLabel = computed(() => props.screenState === 'STARTING' ? 'Запускаем демонстрацию экрана' : props.screenState === 'STOPPING' ? 'Останавливаем демонстрацию экрана' : props.screenState === 'SHARING' ? 'Остановить демонстрацию экрана' : captureAvailable ? 'Начать демонстрацию экрана' : captureMessage)
const screenBusy = computed(() => props.screenState === 'STARTING' || props.screenState === 'STOPPING')
const touchPttDisabled = computed(() => transitioning.value || props.voiceState === 'RECONNECTING' || props.microphonePermissionDenied || props.deafened || props.deafenChanging)
</script>

<template>
  <div :class="dock ? 'voice-actions' : 'voice-room-controls'" role="group" aria-label="Управление голосом">
    <TouchPttButton v-if="channelAvailable && dock && activationMode === 'PTT' && touchPttEnabled" v-action-hint class="voice-icon-button voice-ptt-button" :disabled="touchPttDisabled" :set-pressed="props.setTouchPttPressed" />
    <button v-else-if="channelAvailable" v-action-hint class="voice-icon-button" :class="{ 'voice-icon-button--danger-active': microphoneMuted && !microphonePermissionDenied && activationMode !== 'PTT' || deafened, 'voice-icon-button--warning': microphonePermissionDenied }" type="button" :aria-label="microphoneLabel" :aria-pressed="!microphoneMuted && !microphonePermissionDenied && !deafened" :data-state="microphoneState" :disabled="transitioning || voiceState === 'RECONNECTING' || activationMode === 'PTT' || deafened || deafenChanging" @click="props.toggleMicrophone"><svg class="voice-icon" viewBox="0 0 24 24" aria-hidden="true"><rect x="9" y="2" width="6" height="12" rx="3"/><path d="M5 10v2a7 7 0 0 0 14 0v-2M12 19v3M8 22h8"/><path v-if="microphoneMuted || microphonePermissionDenied || deafened" class="voice-control-slash" d="m3 3 18 18"/></svg></button>
    <button v-if="channelAvailable" v-action-hint class="voice-icon-button" :class="{ 'voice-icon-button--danger-active': deafened }" type="button" :aria-label="deafenLabel" :aria-pressed="deafened" :data-state="deafened ? 'deafened' : 'enabled'" :disabled="transitioning || deafenChanging" @click="props.toggleDeafen"><svg class="voice-icon" viewBox="0 0 24 24" aria-hidden="true"><path d="M3 14v-3a9 9 0 0 1 18 0v3"/><rect x="3" y="12" width="4" height="9" rx="2"/><rect x="17" y="12" width="4" height="9" rx="2"/><path v-if="deafened" class="voice-control-slash" d="m3 3 18 18"/></svg></button>
    <button v-if="channelAvailable" v-action-hint class="voice-icon-button" :class="{ 'voice-icon-button--sharing': screenState === 'SHARING' }" type="button" :aria-label="screenLabel" :aria-pressed="screenState === 'SHARING'" :data-state="screenState.toLowerCase()" :disabled="transitioning || voiceState === 'RECONNECTING' || screenBusy || (screenState !== 'SHARING' && !captureAvailable)" @click="screenState === 'SHARING' ? emit('stopScreen') : emit('startScreen', selectedScreenProfile)"><svg class="voice-icon" :class="{ 'voice-icon--busy': screenBusy }" viewBox="0 0 24 24" aria-hidden="true"><circle v-if="screenBusy" cx="12" cy="12" r="8" stroke-dasharray="32 18"/><template v-else><rect x="2" y="3" width="20" height="14" rx="2"/><path d="M8 21h8M12 17v4"/><path v-if="screenState === 'SHARING'" d="M9 7h6v6H9z"/><path v-else d="m8 11 4-4 4 4M12 7v6"/></template></svg></button>
    <button v-action-hint class="voice-icon-button voice-icon-button--danger voice-room-controls__leave" type="button" aria-label="Выйти из голосового канала" :disabled="voiceState === 'LEAVING'" @click="emit('leave')"><svg class="voice-icon voice-icon--filled" viewBox="0 0 24 24" aria-hidden="true"><path d="M12 9c-3.16 0-6.1.91-8.42 2.44-.37.2-.58.53-.58.9v2.26c0 .47.33.87.78.98l2.74.68c.48.12.99-.1 1.24-.53l1.2-2.01c1.99-.46 4.05-.46 6.04 0l1.2 2.01c.25.42.76.65 1.24.53l2.74-.68c.45-.11.78-.51.78-.98v-2.26c0-.37-.21-.7-.58-.9C18.1 9.91 15.16 9 12 9Z"/></svg></button>
  </div>
</template>
