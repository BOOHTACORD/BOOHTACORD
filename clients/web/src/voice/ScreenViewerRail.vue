<script setup lang="ts">
import { onBeforeUnmount, ref, watch } from 'vue'
import type { ScreenViewerCard } from './screen_viewer_controller'
import { observeHorizontalOverflow } from './screen_rail_overflow'
import { screenPreviewLeaseForParticipant } from './screen_preview/participant_leases'
import { screenPreviewCardVisibility } from './screen_preview/visibility'

const props = withDefaults(defineProps<{ cards: ScreenViewerCard[]; selectedId: string | null; mode?: 'rail' | 'popover' }>(), { mode: 'rail' })
const emit = defineEmits<{ select: [id: string] }>()
const rail = ref<HTMLDivElement | null>(null)
const hasOverflow = ref(false)
type PreviewState = 'loading' | 'available' | 'unavailable'
const previewStates = ref(new Map<string, { url: string; state: PreviewState }>())
let stopObserving: (() => void) | null = null
let stopPreviewObserving: (() => void) | null = null
watch([rail, () => props.mode], ([element, mode]) => {
  stopObserving?.()
  stopObserving = element && mode === 'rail' ? observeHorizontalOverflow(element, (visible) => { hasOverflow.value = visible }) : null
}, { flush: 'post' })
function observePreviewCards(element: HTMLDivElement | null): void {
  stopPreviewObserving?.()
  stopPreviewObserving = null
  if (!element || typeof IntersectionObserver === 'undefined') return
  const cards = Array.from(element.querySelectorAll<HTMLElement>('[data-screen-preview-lease]'))
  const observer = new IntersectionObserver((entries) => entries.forEach((entry) => {
    const card = entry.target as HTMLElement
    const leaseId = card.dataset.screenPreviewLease
    if (leaseId) screenPreviewCardVisibility.setCardVisible(card, leaseId, entry.isIntersecting && entry.intersectionRatio >= 0.25)
  }), { threshold: 0.25 })
  cards.forEach((card) => observer.observe(card))
  stopPreviewObserving = () => { cards.forEach((card) => screenPreviewCardVisibility.forgetCard(card)); observer.disconnect() }
}
watch([rail, () => props.mode, () => props.cards.map((card) => `${card.id}:${screenPreviewLeaseForParticipant(card.participantId) ?? ''}`).join('|')], ([element]) => observePreviewCards(element), { flush: 'post' })
watch(() => props.cards.map(({ id, thumbnailUrl }) => `${id}\u0000${thumbnailUrl ?? ''}`).join('\u0001'), () => {
  const next = new Map<string, { url: string; state: PreviewState }>()
  for (const card of props.cards) {
    if (!card.thumbnailUrl) continue
    const previous = previewStates.value.get(card.id)
    next.set(card.id, previous?.url === card.thumbnailUrl ? previous : { url: card.thumbnailUrl, state: 'loading' })
  }
  previewStates.value = next
}, { immediate: true })
function previewState(stream: ScreenViewerCard): PreviewState {
  return stream.thumbnailUrl ? previewStates.value.get(stream.id)?.state ?? 'loading' : 'loading'
}
function updatePreviewState(stream: ScreenViewerCard, url: string, state: PreviewState): void {
  if (props.cards.find((card) => card.id === stream.id)?.thumbnailUrl !== url) return
  previewStates.value = new Map(previewStates.value).set(stream.id, { url, state })
}
function ownerLabel(stream: ScreenViewerCard): string {
  return stream.isLocal ? 'Ваш экран' : `Экран ${stream.participantName || 'участника'}`
}
function cardLabel(stream: ScreenViewerCard): string {
  return [ownerLabel(stream), 'Эфир', stream.id === props.selectedId ? 'Смотрим' : '', stream.targetProfile ? `Цель: ${stream.targetProfile}` : ''].filter(Boolean).join(' · ')
}
onBeforeUnmount(() => { stopObserving?.(); stopPreviewObserving?.() })
</script>

<template>
  <section class="screen-rail-section" :class="{ 'screen-rail-section--popover': mode === 'popover' }" aria-label="Демонстрации в канале">
    <h3>Демонстрации в канале</h3>
    <div ref="rail" class="screen-cards stream-rail" :class="{ 'has-overflow': hasOverflow, 'stream-rail--popover': mode === 'popover' }" data-testid="stream-rail" aria-label="Выбор демонстрации" :aria-description="hasOverflow ? 'Есть ещё демонстрации справа. Прокрутите список по горизонтали.' : undefined">
      <button v-for="stream in cards" :key="stream.id" data-testid="stream-select" :data-screen-preview-lease="screenPreviewLeaseForParticipant(stream.participantId)" class="screen-card stream-option" :class="{ selected: stream.id === selectedId, 'stream-option--popover': mode === 'popover' }" type="button" :aria-pressed="stream.id === selectedId" :aria-label="cardLabel(stream)" :title="cardLabel(stream)" @click="emit('select', stream.id)">
        <span class="stream-card-preview">
          <img v-if="stream.thumbnailUrl" class="stream-thumbnail" :src="stream.thumbnailUrl" alt="" @load="updatePreviewState(stream, stream.thumbnailUrl, 'available')" @error="updatePreviewState(stream, stream.thumbnailUrl, 'unavailable')">
          <span v-if="!stream.thumbnailUrl || previewState(stream) !== 'available'" class="screen-preview-placeholder" :class="`screen-preview-placeholder--${previewState(stream)}`" :role="mode === 'popover' ? 'status' : undefined" aria-hidden="false">
            <svg viewBox="0 0 24 24" aria-hidden="true"><rect x="3" y="4" width="18" height="13" rx="2"/><path d="M8 21h8m-4-4v4"/></svg>
            <span class="screen-preview-placeholder__title">{{ mode === 'popover' && previewState(stream) === 'loading' ? 'Предпросмотр загружается' : mode === 'popover' ? 'Предпросмотр недоступен' : 'Трансляция идёт' }}</span>
            <span class="screen-preview-placeholder__hint">{{ mode === 'popover' && previewState(stream) === 'unavailable' ? 'Публикация активна, JPEG временно недоступен' : 'Предпросмотр скоро появится' }}</span>
          </span>
          <span class="stream-card-live-badge" aria-hidden="true">Эфир</span>
          <span v-if="stream.id === selectedId" class="stream-card-selected-badge" aria-hidden="true">Смотрим</span>
        </span>
        <span class="stream-option-copy">
          <span class="stream-option-name" :title="ownerLabel(stream)">{{ ownerLabel(stream) }}</span>
          <span v-if="mode === 'popover' && stream.targetProfile" class="stream-option-target">Цель: {{ stream.targetProfile }}</span>
        </span>
      </button>
    </div>
  </section>
</template>
