<script setup lang="ts">
import { onBeforeUnmount, onMounted, ref } from 'vue'
import type { VoiceVolumeParticipant } from './voice_volume_controls'
import { avatarBackground, avatarForeground } from '../design/avatar_color'
import { useAuthorDirectory } from '../identity/author_directory'
import { findParticipantScreen } from './find_participant_screen'
import type { ScreenViewerCard } from './screen_viewer_controller'
import VoiceParticipantStatus from './VoiceParticipantStatus.vue'
import ParticipantScreenPreview from './ParticipantScreenPreview.vue'

const props = withDefaults(defineProps<{ error: string | null; participants: VoiceVolumeParticipant[]; screenStreams: ScreenViewerCard[]; screenWatcherIds?: string[]; ownerScreenWatcherIds?: string[]; ownScreenSharing?: boolean; selectedScreenStreamId: string | null; selfAccountId?: string; selfName: string | null; selfDeafened: boolean; selfMicrophoneMuted: boolean; selfMicrophoneUnavailable: boolean; selfSpeaking: boolean }>(), { screenWatcherIds: () => [], ownerScreenWatcherIds: () => [], ownScreenSharing: false })
const emit = defineEmits<{ setVolume: [id: string, percent: number]; watchScreen: [id: string] }>()
const participantGrid = ref<HTMLElement | null>(null)
const authors = useAuthorDirectory()
function initial(name: string | null | undefined): string { return name?.trim().slice(0, 2).toLocaleUpperCase('ru-RU') || 'У' }
function selfDisplayName(name: string | null): string { return name?.trim() || 'Вы' }
function avatarUrl(accountId: string | null | undefined): string | undefined { return accountId ? authors.avatarUrl(accountId) : undefined }
function screenForParticipant(participantId: string): ScreenViewerCard | null { return findParticipantScreen(props.screenStreams, participantId) }
function localScreen(): ScreenViewerCard | null { return props.screenStreams.find(screen => screen.isLocal) ?? null }
function viewingRemoteScreen(): boolean { return Boolean(props.screenStreams.find(screen => screen.id === props.selectedScreenStreamId && !screen.isLocal)) }
function watcherLabel(): string { return viewingRemoteScreen() ? 'Смотрит эту трансляцию' : 'Смотрит вашу трансляцию' }
function watchesSelectedScreen(participantId: string): boolean {
  if (viewingRemoteScreen()) return props.screenWatcherIds.includes(participantId)
  return props.ownScreenSharing && props.ownerScreenWatcherIds.includes(participantId)
}
function openVolumeMenus(): HTMLDetailsElement[] {
  return Array.from(participantGrid.value?.querySelectorAll<HTMLDetailsElement>('.participant-volume[open]') ?? [])
}
function closeVolumeMenusOutside(event: PointerEvent): void {
  const target = event.target
  if (!(target instanceof Node)) return
  for (const menu of openVolumeMenus()) {
    if (!menu.contains(target)) menu.open = false
  }
}
function closeVolumeMenusOnEscape(event: KeyboardEvent): void {
  if (event.key !== 'Escape') return
  const menus = openVolumeMenus()
  if (!menus.length) return
  event.preventDefault()
  for (const menu of menus) menu.open = false
  menus[0]?.querySelector<HTMLElement>('summary')?.focus()
}
onMounted(() => {
  document.addEventListener('pointerdown', closeVolumeMenusOutside)
  document.addEventListener('keydown', closeVolumeMenusOnEscape)
})
onBeforeUnmount(() => {
  document.removeEventListener('pointerdown', closeVolumeMenusOutside)
  document.removeEventListener('keydown', closeVolumeMenusOnEscape)
})
</script>

<template>
  <section ref="participantGrid" class="voice-participant-volumes participant-grid" aria-label="Участники голосового канала" data-testid="voice-participants">
    <h3 class="gc-sr-only">Участники голосового канала</h3>
    <p v-if="error" class="state state-error participant-grid-message" role="status">{{ error }}</p>
    <article v-for="participant in participants" :key="participant.id" class="participant" :class="[{ talking: participant.speaking && !participant.microphoneMuted }, screenForParticipant(participant.id) ? 'participant--streaming' : 'participant--voice-only']" data-testid="participant-card">
      <ParticipantScreenPreview v-if="screenForParticipant(participant.id)" :screen="screenForParticipant(participant.id)!" :selected="screenForParticipant(participant.id)?.id === selectedScreenStreamId" @select="emit('watchScreen', $event)" />
      <div v-else class="participant-voice-placeholder" aria-label="В голосовом канале">
        <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M3 13v-2a9 9 0 0 1 18 0v2m-18 0h4v6H5a2 2 0 0 1-2-2v-4Zm18 0h-4v6h2a2 2 0 0 0 2-2v-4Z" /></svg>
        <span>В голосовом канале</span>
      </div>
      <div class="participant-card-info">
        <span class="avatar lg" :style="{ backgroundColor: avatarBackground(participant.accountId ?? participant.id), color: avatarForeground(participant.accountId ?? participant.id) }" aria-hidden="true"><img v-if="avatarUrl(participant.accountId)" :src="avatarUrl(participant.accountId)" alt=""><template v-else>{{ initial(participant.name) }}</template></span>
        <div class="participant-card-copy">
          <span class="participant-name">{{ participant.name || 'Участник' }}</span>
          <span v-if="watchesSelectedScreen(participant.id)" class="participant-watcher-indicator" role="img" :aria-label="watcherLabel()" :title="watcherLabel()"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M2.5 12s3.2-6 9.5-6 9.5 6 9.5 6-3.2 6-9.5 6-9.5-6-9.5-6Z"/><circle cx="12" cy="12" r="2.5"/></svg><span>Смотрит</span></span>
        </div>
        <div class="participant-card-actions">
          <VoiceParticipantStatus class="participant-card-status" compact :microphone-muted="participant.microphoneMuted" :speaking="participant.speaking" />
          <details v-if="participant.accountId" class="participant-volume">
            <summary :aria-label="`Настройки громкости ${participant.name || 'участника'}`" title="Настройки участника">•••</summary>
            <label>Громкость · {{ participant.volume }}%<input :aria-label="`Громкость участника ${participant.name || 'участника'}`" :aria-valuetext="`${participant.volume} процентов`" type="range" min="0" max="200" step="1" :value="participant.volume" @input="emit('setVolume', participant.id, Number(($event.target as HTMLInputElement).value))"></label>
          </details>
        </div>
      </div>
    </article>
    <article class="participant participant-self voice-participant-self" :class="[{ talking: selfSpeaking && !selfDeafened && !selfMicrophoneMuted && !selfMicrophoneUnavailable }, localScreen() ? 'participant--streaming' : 'participant--voice-only']" data-testid="participant-card">
      <ParticipantScreenPreview v-if="localScreen()" :screen="localScreen()!" :selected="localScreen()?.id === selectedScreenStreamId" @select="emit('watchScreen', $event)" />
      <div v-else class="participant-voice-placeholder" aria-label="В голосовом канале">
        <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M3 13v-2a9 9 0 0 1 18 0v2m-18 0h4v6H5a2 2 0 0 1-2-2v-4Zm18 0h-4v6h2a2 2 0 0 0 2-2v-4Z" /></svg>
        <span>В голосовом канале</span>
      </div>
      <div class="participant-card-info">
        <span class="avatar lg" :style="{ backgroundColor: avatarBackground(selfAccountId ?? selfName ?? 'Вы'), color: avatarForeground(selfAccountId ?? selfName ?? 'Вы') }" aria-hidden="true"><img v-if="avatarUrl(selfAccountId)" :src="avatarUrl(selfAccountId)" alt=""><template v-else>{{ initial(selfName ?? 'Вы') }}</template></span>
        <div class="participant-card-copy">
          <span class="participant-name">{{ selfDisplayName(selfName) }}</span>
          <span v-if="selfAccountId && viewingRemoteScreen() && screenWatcherIds.includes(selfAccountId)" class="participant-watcher-indicator" role="img" :aria-label="watcherLabel()" :title="watcherLabel()"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M2.5 12s3.2-6 9.5-6 9.5 6 9.5 6-3.2 6-9.5 6-9.5-6-9.5-6Z"/><circle cx="12" cy="12" r="2.5"/></svg><span>Смотрит</span></span>
        </div>
        <div class="participant-card-actions">
          <VoiceParticipantStatus class="participant-card-status" compact :deafened="selfDeafened" :microphone-muted="selfMicrophoneMuted" :microphone-unavailable="selfMicrophoneUnavailable" :speaking="selfSpeaking" />
        </div>
      </div>
    </article>
  </section>
</template>
