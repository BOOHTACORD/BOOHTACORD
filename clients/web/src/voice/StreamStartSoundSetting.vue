<script setup lang="ts">
import { computed } from 'vue'
import { voiceSoundPreferences as preferences } from './sound_playback/runtime'

const enabled = computed(() => preferences.settings.value.started)
function toggle(): void {
  if (preferences.ready.value) void preferences.patch({ started: !enabled.value })
}
</script>

<template>
  <div class="audio-processing-row">
    <div>Звук начала трансляций<small>Сигнал, когда участник начинает показ экрана</small></div>
    <button type="button" role="switch" :aria-label="enabled ? 'Звук начала трансляций включён' : 'Звук начала трансляций выключен'" :aria-checked="enabled" :disabled="!preferences.ready.value" @click="toggle" />
  </div>
</template>
