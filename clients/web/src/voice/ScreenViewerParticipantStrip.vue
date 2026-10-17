<script setup lang="ts">
import { avatarBackground, avatarForeground } from '../design/avatar_color'
import type { ScreenViewerCard } from './screen_viewer_controller'
import type { VoiceVolumeParticipant } from './voice_volume_controls'
import VoiceParticipantStatus from './VoiceParticipantStatus.vue'
import { findParticipantScreen } from './find_participant_screen'

const props = defineProps<{
  participants: VoiceVolumeParticipant[]
  screens: ScreenViewerCard[]
  selfDeafened: boolean
  selfMicrophoneMuted: boolean
  selfMicrophoneUnavailable: boolean
  selfName: string | null
  selfSpeaking: boolean
  ownScreenSharing: boolean
}>()

function initial(name: string | null | undefined): string {
  return name?.trim().slice(0, 2).toLocaleUpperCase('ru-RU') || 'У'
}

function displayName(name: string | null | undefined): string {
  return name?.trim() || 'Вы'
}

function sharesScreen(participantId: string): boolean {
  return Boolean(findParticipantScreen(props.screens, participantId))
}
</script>

<template>
  <section class="voice-viewer-participant-strip" aria-label="Участники голосового канала" data-testid="viewer-participants">
    <div class="voice-viewer-participant-summary">
      <strong>Участники</strong>
      <span>{{ participants.length + 1 }} в комнате</span>
    </div>
    <ul aria-label="Состав голосового канала" tabindex="0">
      <li class="voice-viewer-participant" :class="{ 'is-speaking': selfSpeaking && !selfDeafened && !selfMicrophoneMuted && !selfMicrophoneUnavailable }">
        <span class="voice-viewer-participant-avatar" :style="{ backgroundColor: avatarBackground(selfName ?? 'Вы'), color: avatarForeground(selfName ?? 'Вы') }" aria-hidden="true">{{ initial(selfName) }}</span>
        <span class="voice-viewer-participant-name" :title="displayName(selfName)">{{ displayName(selfName) }}</span>
        <span v-if="ownScreenSharing" class="voice-viewer-stream-indicator" role="img" aria-label="Показывает экран" title="Показывает экран"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M3 4h18v13H3zM8 21h8m-4-4v4" /></svg></span>
        <VoiceParticipantStatus compact :deafened="selfDeafened" :microphone-muted="selfMicrophoneMuted" :microphone-unavailable="selfMicrophoneUnavailable" :speaking="selfSpeaking" />
      </li>
      <li v-for="participant in participants" :key="participant.id" class="voice-viewer-participant" :class="{ 'is-speaking': participant.speaking && !participant.microphoneMuted }">
        <span class="voice-viewer-participant-avatar" :style="{ backgroundColor: avatarBackground(participant.accountId ?? participant.id), color: avatarForeground(participant.accountId ?? participant.id) }" aria-hidden="true">{{ initial(participant.name) }}</span>
        <span class="voice-viewer-participant-name" :title="displayName(participant.name)">{{ displayName(participant.name) }}</span>
        <span v-if="sharesScreen(participant.id)" class="voice-viewer-stream-indicator" role="img" aria-label="Показывает экран" title="Показывает экран"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M3 4h18v13H3zM8 21h8m-4-4v4" /></svg></span>
        <VoiceParticipantStatus compact :microphone-muted="participant.microphoneMuted" :speaking="participant.speaking" />
      </li>
    </ul>
  </section>
</template>
