<script setup lang="ts">
import type { VoiceVolumeParticipant } from './voice_volume_controls'
import VoiceParticipantStatus from './VoiceParticipantStatus.vue'

defineProps<{ error: string | null; participants: VoiceVolumeParticipant[]; selfDeafened?: boolean; selfMicrophoneMuted: boolean; selfMicrophoneUnavailable: boolean }>()

function initial(name: string | undefined): string {
  return name?.trim().slice(0, 1).toLocaleUpperCase('ru-RU') || 'У'
}
</script>

<template>
  <section class="voice-participant-strip" aria-label="Участники голосового канала">
    <h3>В голосовом канале <span>{{ participants.length + 1 }}</span></h3>
    <p v-if="error" class="state state-error" role="status">{{ error }}</p>
    <ul>
      <li class="voice-participant-self">
        <span class="voice-strip-avatar" aria-hidden="true">{{ initial('Вы') }}</span>
        <span class="voice-strip-name">Вы</span>
        <VoiceParticipantStatus :deafened="selfDeafened" :microphone-muted="selfMicrophoneMuted" :microphone-unavailable="selfMicrophoneUnavailable" />
      </li>
      <li v-if="participants.length === 0" class="voice-strip-empty state">Другие участники пока не подключены.</li>
      <li v-for="participant in participants" :key="participant.id" :class="{ 'is-speaking': participant.speaking && !participant.deafened }">
        <span class="voice-strip-avatar" aria-hidden="true">{{ initial(participant.name) }}</span>
        <span class="voice-strip-name">{{ participant.name || 'Участник' }}</span>
        <VoiceParticipantStatus :deafened="participant.deafened" :microphone-muted="participant.microphoneMuted" :speaking="participant.speaking" />
      </li>
    </ul>
  </section>
</template>
