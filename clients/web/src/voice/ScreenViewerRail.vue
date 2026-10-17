<script setup lang="ts">
import { onBeforeUnmount, ref, watch } from 'vue'
import { avatarBackground, avatarForeground } from '../design/avatar_color'
import type { ScreenViewerCard } from './screen_viewer_controller'
import { observeHorizontalOverflow } from './screen_rail_overflow'
import { screenPreviewLeaseForParticipant } from './screen_preview/participant_leases'
import { screenPreviewCardVisibility } from './screen_preview/visibility'

const props = defineProps<{ cards: ScreenViewerCard[]; selectedId: string | null }>()
const emit = defineEmits<{ select: [id: string] }>()
const rail = ref<HTMLDivElement | null>(null)
const hasOverflow = ref(false)
let stopObserving: (() => void) | null = null
let stopPreviewObserving: (() => void) | null = null
watch(rail, (element) => {
  stopObserving?.()
  stopObserving = element ? observeHorizontalOverflow(element, (visible) => { hasOverflow.value = visible }) : null
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
watch([rail, () => props.cards.map((card) => `${card.id}:${screenPreviewLeaseForParticipant(card.participantId) ?? ''}`).join('|')], ([element]) => observePreviewCards(element), { flush: 'post' })
onBeforeUnmount(() => { stopObserving?.(); stopPreviewObserving?.() })
const initials = (name: string) => name.trim().slice(0, 2).toLocaleUpperCase('ru-RU') || 'У'
</script>

<template>
  <section class="screen-rail-section" aria-label="Демонстрации в канале">
    <h3>Демонстрации в канале</h3>
    <div ref="rail" class="screen-cards stream-rail" :class="{ 'has-overflow': hasOverflow }" data-testid="stream-rail" aria-label="Выбор демонстрации" :aria-description="hasOverflow ? 'Есть ещё демонстрации справа. Прокрутите список по горизонтали.' : undefined">
      <button v-for="stream in cards" :key="stream.id" data-testid="stream-select" :data-screen-preview-lease="screenPreviewLeaseForParticipant(stream.participantId)" class="screen-card stream-option" :class="{ selected: stream.id === selectedId }" type="button" :aria-pressed="stream.id === selectedId" @click="emit('select', stream.id)">
        <span class="stream-card-preview"><img v-if="stream.thumbnailUrl" class="stream-thumbnail" :src="stream.thumbnailUrl" alt=""><span v-else class="stream-avatar" :style="{ backgroundColor: avatarBackground(stream.accountId ?? stream.participantId), color: avatarForeground(stream.accountId ?? stream.participantId) }" aria-hidden="true">{{ initials(stream.participantName) }}</span></span>
        <span class="stream-option-copy"><span>{{ stream.isLocal ? 'Ваш экран' : `Экран ${stream.participantName || 'участника'}` }}</span><b v-if="stream.id === selectedId">ЭФИР</b></span>
      </button>
    </div>
  </section>
</template>
