<script setup lang="ts">
defineProps<{ adjustable: boolean; deafened: boolean; muted: boolean; volume: number }>()
const emit = defineEmits<{ toggle: []; setVolume: [percent: number] }>()
</script>

<template>
  <button class="screen-audio-toggle stream-tool-button" type="button" :aria-label="muted || volume === 0 ? 'Включить звук трансляции' : 'Выключить звук трансляции'" :aria-pressed="!muted && volume > 0" :disabled="deafened" @click="emit('toggle')"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="m11 5-6 4H2v6h3l6 4V5Z"/><path v-if="!muted && volume > 0" d="M15 8a6 6 0 0 1 0 8M18 5a10 10 0 0 1 0 14"/><path v-else d="m3 3 18 18"/></svg></button>
  <label v-if="adjustable" class="volume-control">
    <span class="gc-sr-only">Громкость аудиодорожки · {{ volume }}%</span>
    <input aria-label="Громкость звука выбранной демонстрации" type="range" min="0" max="200" step="1" :value="volume" :style="{ '--screen-audio-level': `${volume / 2}%` }" @input="emit('setVolume', Number(($event.target as HTMLInputElement).value))">
    <output>{{ volume }}%</output>
  </label>
</template>
