<script setup lang="ts">
import { nextTick, onBeforeUnmount, ref, watch } from 'vue'
import { avatarBackground, avatarForeground } from '../design/avatar_color'
import { useAuthorDirectory } from '../identity/author_directory'
import type { ScreenViewerCard } from './screen_viewer_controller'
import type { VoiceVolumeParticipant } from './voice_volume_controls'
import VoiceParticipantStatus from './VoiceParticipantStatus.vue'
import { findParticipantScreen } from './find_participant_screen'

const props = defineProps<{
  participants: VoiceVolumeParticipant[]
  screens: ScreenViewerCard[]
  selectedId: string | null
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
const roster = ref<HTMLUListElement | null>(null)
const overflowingNames = ref<Set<string>>(new Set())
let nameResizeObserver: ResizeObserver | null = null

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

function viewingRemoteScreen(): boolean {
  return Boolean(props.screens.find(screen => screen.id === props.selectedId && !screen.isLocal))
}

function showAudience(): boolean {
  return props.ownScreenSharing || viewingRemoteScreen()
}

function audienceLabel(): string {
  return `Активные сеансы просмотра: ${props.screenWatcherIds?.length ?? 0}. Это не подтверждение внимания.`
}

function watcherLabel(): string {
  return viewingRemoteScreen() ? 'Смотрит эту трансляцию' : 'Смотрит вашу трансляцию'
}

function watchesSelectedScreen(participantId: string | undefined): boolean {
  return showAudience() && Boolean(participantId && props.screenWatcherIds?.includes(participantId))
}

function isOverflowing(key: string): boolean {
  return overflowingNames.value.has(key)
}

function updateNameOverflow(): void {
  const next = new Set<string>()
  roster.value?.querySelectorAll<HTMLElement>('[data-roster-name]').forEach((name) => {
    const key = name.dataset.rosterName
    if (key && (name.scrollHeight > name.clientHeight + 1 || name.scrollWidth > name.clientWidth + 1)) next.add(key)
  })
  overflowingNames.value = next
}

function observeNames(element: HTMLUListElement | null): void {
  nameResizeObserver?.disconnect()
  nameResizeObserver = null
  if (!element || typeof ResizeObserver === 'undefined') return
  nameResizeObserver = new ResizeObserver(updateNameOverflow)
  nameResizeObserver.observe(element)
  element.querySelectorAll<HTMLElement>('[data-roster-name]').forEach((name) => nameResizeObserver?.observe(name))
  void nextTick(updateNameOverflow)
}

watch(roster, observeNames, { flush: 'post' })
watch(() => [props.selfName, ...props.participants.map((participant) => participant.name)].join('\u0000'), () => { void nextTick(updateNameOverflow) }, { flush: 'post' })
onBeforeUnmount(() => nameResizeObserver?.disconnect())
</script>

<template>
  <section class="voice-viewer-participant-strip" aria-label="Участники голосового канала" data-testid="viewer-participants">
    <div class="voice-viewer-participant-summary">
      <strong>Участники</strong>
      <span>{{ participants.length + 1 }} в комнате</span>
      <span v-if="showAudience()" class="voice-viewer-watcher-count" role="status" :aria-label="audienceLabel()" :title="audienceLabel()">
        <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M2.5 12s3.2-6 9.5-6 9.5 6 9.5 6-3.2 6-9.5 6-9.5-6-9.5-6Z" /><circle cx="12" cy="12" r="2.5" /></svg>
        <span><span class="voice-viewer-watcher-count-label">Зрители · </span>{{ screenWatcherIds?.length ?? 0 }}</span>
      </span>
    </div>
    <ul ref="roster" aria-label="Состав голосового канала" tabindex="0">
      <li class="voice-viewer-participant" :class="{ 'is-speaking': selfSpeaking && !selfDeafened && !selfMicrophoneMuted && !selfMicrophoneUnavailable }">
        <span class="voice-viewer-participant-avatar" :style="{ backgroundColor: avatarBackground(selfName ?? 'Вы'), color: avatarForeground(selfName ?? 'Вы') }" aria-hidden="true"><img v-if="avatarUrl(selfAccountId)" :src="avatarUrl(selfAccountId)" alt=""><template v-else>{{ initial(selfName) }}</template></span>
        <span class="voice-viewer-participant-name-wrap">
          <span class="voice-viewer-participant-name" :data-roster-name="'self'" :data-full-name="displayName(selfName)" :title="displayName(selfName)" :aria-label="displayName(selfName)" :aria-describedby="isOverflowing('self') ? 'viewer-name-tooltip-self' : undefined" :tabindex="isOverflowing('self') ? 0 : undefined">{{ displayName(selfName) }}</span>
          <span v-if="isOverflowing('self')" id="viewer-name-tooltip-self" class="voice-viewer-participant-name-tooltip" role="tooltip">{{ displayName(selfName) }}</span>
          <span class="voice-viewer-participant-you">Вы</span>
        </span>
        <span class="voice-viewer-participant-indicators">
          <span v-if="watchesSelectedScreen(selfAccountId)" class="voice-viewer-watching-indicator" role="img" :aria-label="watcherLabel()" :title="watcherLabel()"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M2.5 12s3.2-6 9.5-6 9.5 6 9.5 6-3.2 6-9.5 6-9.5-6-9.5-6Z"/><circle cx="12" cy="12" r="2.5"/></svg></span>
          <span v-if="ownScreenSharing" class="voice-viewer-stream-indicator" role="img" aria-label="Показывает экран" title="Показывает экран"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M3 4h18v13H3zM8 21h8m-4-4v4" /></svg></span>
          <VoiceParticipantStatus compact :deafened="selfDeafened" :microphone-muted="selfMicrophoneMuted" :microphone-unavailable="selfMicrophoneUnavailable" :speaking="selfSpeaking" />
        </span>
      </li>
      <li v-for="(participant, index) in participants" :key="participant.id" class="voice-viewer-participant" :class="{ 'is-speaking': participant.speaking && !participant.microphoneMuted && !participant.deafened }">
        <span class="voice-viewer-participant-avatar" :style="{ backgroundColor: avatarBackground(participant.accountId ?? participant.id), color: avatarForeground(participant.accountId ?? participant.id) }" aria-hidden="true"><img v-if="avatarUrl(participant.accountId)" :src="avatarUrl(participant.accountId)" alt=""><template v-else>{{ initial(participant.name) }}</template></span>
        <span class="voice-viewer-participant-name-wrap">
          <span class="voice-viewer-participant-name" :data-roster-name="`participant-${index}`" :data-full-name="displayName(participant.name)" :title="displayName(participant.name)" :aria-label="displayName(participant.name)" :aria-describedby="isOverflowing(`participant-${index}`) ? `viewer-name-tooltip-${index}` : undefined" :tabindex="isOverflowing(`participant-${index}`) ? 0 : undefined">{{ displayName(participant.name) }}</span>
          <span v-if="isOverflowing(`participant-${index}`)" :id="`viewer-name-tooltip-${index}`" class="voice-viewer-participant-name-tooltip" role="tooltip">{{ displayName(participant.name) }}</span>
        </span>
        <span class="voice-viewer-participant-indicators">
          <span v-if="watchesSelectedScreen(participant.id)" class="voice-viewer-watching-indicator" role="img" :aria-label="watcherLabel()" :title="watcherLabel()"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M2.5 12s3.2-6 9.5-6 9.5 6 9.5 6-3.2 6-9.5 6-9.5-6-9.5-6Z"/><circle cx="12" cy="12" r="2.5"/></svg></span>
          <span v-if="sharesScreen(participant.id)" class="voice-viewer-stream-indicator" role="img" aria-label="Показывает экран" title="Показывает экран"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M3 4h18v13H3zM8 21h8m-4-4v4" /></svg></span>
          <VoiceParticipantStatus compact :deafened="participant.deafened" :microphone-muted="participant.microphoneMuted" :speaking="participant.speaking" />
        </span>
      </li>
    </ul>
  </section>
</template>
