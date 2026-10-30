<script setup lang="ts">
import { computed, onBeforeUnmount, ref, watch } from 'vue'
import type { ScreenViewerCard } from './screen_viewer_controller'
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

const caption = computed(() => {
  const mode = props.screen.descriptor?.mode
  const profile = props.screen.targetProfile
  if (mode) return `${mode === 'motion' ? 'Плавность' : 'Текст'}${profile ? ` · ${profile}` : ''}`
  return profile ? `Экран · ${profile}` : 'Демонстрация экрана'
})
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
    <span v-else class="screen-preview-placeholder" aria-hidden="true">
      <svg viewBox="0 0 24 24"><rect x="3" y="4" width="18" height="13" rx="2"/><path d="M8 21h8m-4-4v4"/></svg>
      <span class="screen-preview-placeholder__title">Трансляция идёт</span>
      <span class="screen-preview-placeholder__hint">Предпросмотр скоро появится</span>
    </span>
    <span class="participant-screen-preview__caption">{{ caption }}</span>
    <span class="participant-screen-preview__live"><span aria-hidden="true"></span>ЭФИР</span>
    <span v-if="screen.thumbnailUrl" class="participant-screen-preview__play" aria-hidden="true">
      <svg viewBox="0 0 24 24"><path d="m9 6 10 6-10 6z" /></svg>
    </span>
  </button>
</template>
