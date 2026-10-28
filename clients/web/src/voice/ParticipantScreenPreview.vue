<script setup lang="ts">
import { computed, onBeforeUnmount, ref, watch } from 'vue'
import type { ScreenViewerCard } from './screen_viewer_controller'
import { avatarBackground, avatarForeground } from '../design/avatar_color'
import { screenPreviewLeaseForParticipant } from './screen_preview/participant_leases'
import { screenPreviewCardVisibility } from './screen_preview/visibility'

const props = defineProps<{ screen: ScreenViewerCard; selected?: boolean }>()
const emit = defineEmits<{ select: [id: string] }>()
const preview = ref<HTMLButtonElement | null>(null)
const leaseId = computed(() => screenPreviewLeaseForParticipant(props.screen.participantId))
let observer: IntersectionObserver | null = null

function stopObserving(): void {
  if (preview.value) screenPreviewCardVisibility.forgetCard(preview.value)
  observer?.disconnect()
  observer = null
}

function observePreview(): void {
  stopObserving()
  const element = preview.value
  const lease = leaseId.value
  if (!element || !lease || typeof IntersectionObserver === 'undefined') return

  observer = new IntersectionObserver((entries) => entries.forEach((entry) => {
    screenPreviewCardVisibility.setCardVisible(element, lease, entry.isIntersecting && entry.intersectionRatio >= 0.25)
  }), { threshold: 0.25 })
  observer.observe(element)
}

watch([preview, leaseId], observePreview, { flush: 'post' })
onBeforeUnmount(stopObserving)

const initials = computed(() => props.screen.participantName.trim().slice(0, 2).toLocaleUpperCase('ru-RU') || 'У')
</script>

<template>
  <button
    ref="preview"
    class="participant-screen-preview"
    :class="{ 'is-selected': selected }"
    :data-screen-preview-lease="leaseId"
    data-testid="participant-screen-preview"
    type="button"
    :aria-label="`Открыть трансляцию ${screen.participantName || 'участника'}`"
    :aria-pressed="selected === true"
    @click="emit('select', screen.id)"
  >
    <img v-if="screen.thumbnailUrl" class="participant-screen-preview__image" :src="screen.thumbnailUrl" alt="">
    <span
      v-else
      class="participant-screen-preview__empty"
      :style="{ backgroundColor: avatarBackground(screen.accountId ?? screen.participantId), color: avatarForeground(screen.accountId ?? screen.participantId) }"
      aria-hidden="true"
    >{{ initials }}</span>
    <span class="participant-screen-preview__live"><span aria-hidden="true"></span>ЭФИР</span>
    <span class="participant-screen-preview__open" aria-hidden="true">
      <svg viewBox="0 0 24 24"><path d="M4 5h16v11H4zM9 20h6m-3-4v4" /></svg>
    </span>
  </button>
</template>
