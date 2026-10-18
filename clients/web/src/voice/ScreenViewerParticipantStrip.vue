<script setup lang="ts">
import { avatarBackground, avatarForeground } from '../design/avatar_color'
import { useAuthorDirectory } from '../identity/author_directory'
import type { ScreenViewerCard } from './screen_viewer_controller'
import type { VoiceVolumeParticipant } from './voice_volume_controls'
import VoiceParticipantStatus from './VoiceParticipantStatus.vue'
import { findParticipantScreen } from './find_participant_screen'

const props = defineProps<{
  participants: VoiceVolumeParticipant[]
  screens: ScreenViewerCard[]
  screenWatcherIds?: string[]
  selfDeafened: boolean
  selfMicrophoneMuted: boolean
  selfMicrophoneUnavailable: boolean
  selfName: string | null
  selfAccountId?: string
  selfSpeaking: boolean
  ownScreenSharing: boolean
}>()
const authors = useAuthorDirectory()

function initial(name: string | null | undefined): string {
  return name?.trim().slice(0, 2).toLocaleUpperCase('ru-RU') || 'У'
}

function displayName(name: string | null | undefined): string {
  return name?.trim() || 'Вы'
}

function avatarUrl(accountId: string | null | undefined): string | undefined {
  return accountId ? authors.avatarUrl(accountId) : undefined
}

function sharesScreen(participantId: string): boolean {
  return Boolean(findParticipantScreen(props.screens, participantId))
}

function watchesOwnScreen(participantId: string): boolean {
  return props.ownScreenSharing && Boolean(props.screenWatcherIds?.includes(participantId))
}
</script>

<template>
  <section class="voice-viewer-participant-strip" aria-label="Участники голосового канала" data-testid="viewer-participants">
    <div class="voice-viewer-participant-summary">
      <strong>Участники</strong>
      <span>{{ participants.length + 1 }} в комнате</span>
      <span v-if="ownScreenSharing" class="voice-viewer-watcher-count" role="status" :aria-label="`Зрители трансляции: ${screenWatcherIds?.length ?? 0}`" :title="`Зрители трансляции: ${screenWatcherIds?.length ?? 0}`">
        <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M2.5 12s3.2-6 9.5-6 9.5 6 9.5 6-3.2 6-9.5 6-9.5-6-9.5-6Z" /><circle cx="12" cy="12" r="2.5" /></svg>
        <span><span class="voice-viewer-watcher-count-label">Зрители · </span>{{ screenWatcherIds?.length ?? 0 }}</span>
      </span>
    </div>
    <ul aria-label="Состав голосового канала" tabindex="0">
      <li class="voice-viewer-participant" :class="{ 'is-speaking': selfSpeaking && !selfDeafened && !selfMicrophoneMuted && !selfMicrophoneUnavailable }">
        <span class="voice-viewer-participant-avatar" :style="{ backgroundColor: avatarBackground(selfName ?? 'Вы'), color: avatarForeground(selfName ?? 'Вы') }" aria-hidden="true"><img v-if="avatarUrl(selfAccountId)" :src="avatarUrl(selfAccountId)" alt=""><template v-else>{{ initial(selfName) }}</template></span>
        <span class="voice-viewer-participant-name" :title="displayName(selfName)">{{ displayName(selfName) }}</span>
        <span v-if="ownScreenSharing" class="voice-viewer-stream-indicator" role="img" aria-label="Показывает экран" title="Показывает экран"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M3 4h18v13H3zM8 21h8m-4-4v4" /></svg></span>
        <VoiceParticipantStatus compact :deafened="selfDeafened" :microphone-muted="selfMicrophoneMuted" :microphone-unavailable="selfMicrophoneUnavailable" :speaking="selfSpeaking" />
      </li>
      <li v-for="participant in participants" :key="participant.id" class="voice-viewer-participant" :class="{ 'is-speaking': participant.speaking && !participant.microphoneMuted }">
        <span class="voice-viewer-participant-avatar" :style="{ backgroundColor: avatarBackground(participant.accountId ?? participant.id), color: avatarForeground(participant.accountId ?? participant.id) }" aria-hidden="true"><img v-if="avatarUrl(participant.accountId)" :src="avatarUrl(participant.accountId)" alt=""><template v-else>{{ initial(participant.name) }}</template></span>
        <span class="voice-viewer-participant-name" :title="displayName(participant.name)">{{ displayName(participant.name) }}</span>
        <span v-if="watchesOwnScreen(participant.id)" class="voice-viewer-watching-indicator" role="img" aria-label="Смотрит вашу трансляцию" title="Смотрит вашу трансляцию"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M2.5 12s3.2-6 9.5-6 9.5 6 9.5 6-3.2 6-9.5 6-9.5-6-9.5-6Z"/><circle cx="12" cy="12" r="2.5"/></svg></span>
        <span v-if="sharesScreen(participant.id)" class="voice-viewer-stream-indicator" role="img" aria-label="Показывает экран" title="Показывает экран"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M3 4h18v13H3zM8 21h8m-4-4v4" /></svg></span>
        <VoiceParticipantStatus compact :microphone-muted="participant.microphoneMuted" :speaking="participant.speaking" />
      </li>
    </ul>
  </section>
</template>
