<script setup lang="ts">
import type { ScreenShareState, VoiceConnectionState } from './connection_store'
import type { ScreenProfile } from './livekit_gateway'
import type { ScreenDiagnostics } from './screen_diagnostics'
import type { ScreenViewerCard } from './screen_viewer_controller'
import type { VoiceVolumeParticipant } from './voice_volume_controls'
import VoiceRoomFooter from './VoiceRoomFooter.vue'
import type { VoiceActivationMode } from './activation_store'
import ScreenViewerRail from './ScreenViewerRail.vue'
import VoiceParticipantVolumes from './VoiceParticipantVolumes.vue'
import VoiceRoomControls from './VoiceRoomControls.vue'
import { screenCaptureSupported, screenCaptureUnavailableMessage } from './screen_capture_support'

withDefaults(defineProps<{ roomName: string; voiceState: VoiceConnectionState; screenState: ScreenShareState; screenError: string | null; screenDiagnostics: ScreenDiagnostics; screenProfile: ScreenProfile | null; selectedScreenProfile: ScreenProfile; screenViewerCards: ScreenViewerCard[]; screenWatcherIds?: string[]; voiceVolumeError: string | null; voiceVolumeParticipants: VoiceVolumeParticipant[]; selfAccountId?: string; selfName: string | null; selfDeafened: boolean; selfMicrophoneMuted: boolean; selfMicrophoneUnavailable: boolean; selfSpeaking: boolean; toggleMicrophone: () => void; toggleDeafen: () => void; activationMode?: VoiceActivationMode; deafenChanging?: boolean }>(), { activationMode: 'VAD', deafenChanging: false, screenWatcherIds: () => [] })
const captureAvailable = screenCaptureSupported()
const captureMessage = screenCaptureUnavailableMessage()
const emit = defineEmits<{ startScreen: [profile: ScreenProfile]; stopScreen: []; setVolume: [id: string, volume: number]; watchScreen: [id: string]; leave: []; refreshScreen: [] }>()
</script>

<template>
  <div class="room-intro"><VoiceRoomFooter :channel-name="roomName" :state="voiceState" :activation-mode="activationMode" :participant-count="voiceVolumeParticipants.length + 1" :screen-count="screenViewerCards.length" /></div>
  <p v-if="!captureAvailable && voiceState !== 'LEAVING'" class="state" role="status">{{ captureMessage }}</p>
  <p v-if="screenError" class="state state-error" role="alert">{{ screenError }}</p>
  <ScreenViewerRail v-if="voiceState !== 'LEAVING' && screenViewerCards.length" :cards="screenViewerCards" :selected-id="null" @select="emit('watchScreen', $event)" />
  <VoiceParticipantVolumes v-if="voiceState !== 'LEAVING'" :style="{ '--voice-columns': Math.min(4, voiceVolumeParticipants.length + 1) }" :error="voiceVolumeError" :participants="voiceVolumeParticipants" :screen-streams="screenViewerCards" :screen-watcher-ids="screenWatcherIds" :own-screen-sharing="screenState === 'SHARING'" :selected-screen-stream-id="null" :self-account-id="selfAccountId" :self-name="selfName" :self-deafened="selfDeafened" :self-microphone-muted="selfMicrophoneMuted" :self-microphone-unavailable="selfMicrophoneUnavailable" :self-speaking="selfSpeaking" @set-volume="(id, volume) => emit('setVolume', id, volume)" @watch-screen="emit('watchScreen', $event)" />
  <VoiceRoomControls :activation-mode="activationMode" :deafen-changing="deafenChanging" :microphone-permission-denied="selfMicrophoneUnavailable" :voice-state="voiceState" :screen-state="screenState" :selected-screen-profile="selectedScreenProfile" :microphone-muted="selfMicrophoneMuted" :deafened="selfDeafened" :toggle-microphone="toggleMicrophone" :toggle-deafen="toggleDeafen" @start-screen="emit('startScreen', $event)" @stop-screen="emit('stopScreen')" @leave="emit('leave')" />
</template>
