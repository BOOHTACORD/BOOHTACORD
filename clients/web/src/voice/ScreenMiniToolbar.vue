<script setup lang="ts">
defineProps<{ name: string; paused: boolean; ended: boolean; ready: boolean; hasAudio: boolean; muted: boolean; deafened: boolean }>()
const emit = defineEmits<{ pause: []; audio: []; expand: []; close: [] }>()
</script>
<template>
  <div class="screen-mini-toolbar">
    <strong :title="name">{{ name }}</strong>
    <div class="screen-mini-actions" role="group" aria-label="Управление мини-плеером">
      <button type="button" :disabled="ended || !ready" :aria-label="paused ? 'Продолжить трансляцию' : 'Приостановить трансляцию'" :title="paused ? 'Продолжить трансляцию' : 'Приостановить трансляцию'" :aria-pressed="paused" @click="emit('pause')"><svg viewBox="0 0 24 24" aria-hidden="true"><path v-if="paused" d="m8 4 12 8-12 8Z"/><path v-else d="M8 4v16M16 4v16"/></svg></button>
      <button type="button" :disabled="!hasAudio || deafened || ended" :aria-label="muted || deafened ? 'Включить звук трансляции' : 'Выключить звук трансляции'" :title="!hasAudio ? 'У трансляции нет звука' : deafened ? 'Удалённый звук выключен' : muted ? 'Включить звук трансляции' : 'Выключить звук трансляции'" :aria-pressed="!muted && !deafened && hasAudio" @click="emit('audio')"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M3 9v6h4l5 4V5L7 9H3M16 8a5 5 0 0 1 0 8"/><path v-if="muted || deafened || !hasAudio" d="m3 3 18 18"/></svg></button>
      <button type="button" aria-label="Развернуть на всю область" title="Развернуть на всю область" @click="emit('expand')"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M8 3H3v5M16 3h5v5M3 16v5h5M21 16v5h-5"/></svg></button>
      <button type="button" aria-label="Остановить просмотр" title="Остановить просмотр" @click="emit('close')"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="m6 6 12 12M6 18 18 6"/></svg></button>
    </div>
  </div>
</template>
