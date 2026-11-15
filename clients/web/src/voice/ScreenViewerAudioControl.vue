<script setup lang="ts">
import { onBeforeUnmount, onMounted, ref, watch } from 'vue'

const props = withDefaults(defineProps<{ adjustable: boolean; compact?: boolean; muted: boolean; volume: number }>(), { compact: false })
const emit = defineEmits<{ toggle: []; setVolume: [percent: number]; volumePanel: [open: boolean] }>()
const root = ref<HTMLDivElement | null>(null)
const panelOpen = ref(false)

function closePanel(restoreFocus = false): void {
  if (!panelOpen.value) return
  panelOpen.value = false
  emit('volumePanel', false)
  if (restoreFocus) root.value?.querySelector<HTMLButtonElement>('.screen-audio-toggle')?.focus({ preventScroll: true })
}

function togglePanel(): void {
  if (panelOpen.value) closePanel(true)
  else {
    panelOpen.value = true
    emit('volumePanel', true)
  }
}

function onDocumentPointerDown(event: PointerEvent): void {
  if (event.target instanceof Node && !root.value?.contains(event.target)) closePanel()
}

function onKeydown(event: KeyboardEvent): void {
  if (event.key !== 'Escape' || !panelOpen.value) return
  event.preventDefault()
  event.stopPropagation()
  closePanel(true)
}

watch(() => props.compact && props.adjustable, available => {
  if (!available) closePanel()
})

onMounted(() => document.addEventListener('pointerdown', onDocumentPointerDown, true))
onBeforeUnmount(() => document.removeEventListener('pointerdown', onDocumentPointerDown, true))
</script>

<template>
  <div ref="root" class="screen-audio-control" @keydown="onKeydown">
    <button
      class="screen-audio-toggle stream-tool-button"
      type="button"
      :aria-label="compact && adjustable
        ? panelOpen ? 'Закрыть регулировку громкости трансляции' : 'Открыть регулировку громкости трансляции'
        : muted || volume === 0 ? 'Включить звук трансляции' : 'Выключить звук трансляции'"
      :aria-pressed="compact && adjustable ? undefined : !muted && volume > 0"
      :aria-expanded="compact && adjustable ? panelOpen : undefined"
      :aria-controls="compact && adjustable ? 'screen-viewer-volume-panel' : undefined"
      @click="compact && adjustable ? togglePanel() : emit('toggle')"
    >
      <svg viewBox="0 0 24 24" aria-hidden="true"><path d="m11 5-6 4H2v6h3l6 4V5Z"/><path v-if="!muted && volume > 0" d="M15 8a6 6 0 0 1 0 8M18 5a10 10 0 0 1 0 14"/><path v-else d="m3 3 18 18"/></svg>
    </button>

    <label v-if="adjustable && !compact" class="volume-control">
      <span class="gc-sr-only">Громкость аудиодорожки · {{ volume }}%</span>
      <input aria-label="Громкость звука выбранной демонстрации" type="range" min="0" max="200" step="1" :value="volume" :style="{ '--screen-audio-level': `${volume / 2}%` }" @input="emit('setVolume', Number(($event.target as HTMLInputElement).value))">
      <output>{{ volume }}%</output>
    </label>

    <div v-show="compact && adjustable && panelOpen" id="screen-viewer-volume-panel" class="screen-volume-popover" role="group" aria-label="Громкость звука выбранной демонстрации">
      <label class="volume-control">
        <span>Громкость</span>
        <input aria-label="Громкость звука выбранной демонстрации" type="range" min="0" max="200" step="1" :value="volume" :style="{ '--screen-audio-level': `${volume / 2}%` }" @input="emit('setVolume', Number(($event.target as HTMLInputElement).value))">
        <output>{{ volume }}%</output>
      </label>
      <button class="stream-tool-button screen-volume-mute" type="button" :aria-label="muted || volume === 0 ? 'Включить звук трансляции' : 'Выключить звук трансляции'" :aria-pressed="!muted && volume > 0" @click="emit('toggle')">
        <svg viewBox="0 0 24 24" aria-hidden="true"><path d="m11 5-6 4H2v6h3l6 4V5Z"/><path v-if="!muted && volume > 0" d="M15 8a6 6 0 0 1 0 8M18 5a10 10 0 0 1 0 14"/><path v-else d="m3 3 18 18"/></svg>
        <span>{{ muted || volume === 0 ? 'Включить звук' : 'Выключить звук' }}</span>
      </button>
    </div>
  </div>
</template>
