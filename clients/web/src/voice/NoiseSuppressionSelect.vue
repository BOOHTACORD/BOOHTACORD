<script setup lang="ts">
import { deepfilterReleaseEnabled, rnnoiseReleaseEnabled } from './noise_suppression/capabilities'
import type { NoiseSuppressionMode } from './noise_suppression/types'
defineProps<{ mode: NoiseSuppressionMode }>()
const emit = defineEmits<{ change: [mode: NoiseSuppressionMode] }>()
</script>

<template>
  <label class="audio-processing-row audio-processing-row--noise">
    <span>Шумоподавление<small>Уменьшает фоновый шум</small></span>
    <select class="gc-field" aria-label="Режим шумоподавления" :value="mode" @change="emit('change', ($event.target as HTMLSelectElement).value as NoiseSuppressionMode)">
      <option value="off">Выключено</option>
      <option value="browser">Стандартное — WebRTC</option>
      <option v-if="rnnoiseReleaseEnabled()" value="rnnoise">RNNoise — экспериментальное</option>
      <option v-if="!rnnoiseReleaseEnabled() && mode === 'rnnoise'" value="rnnoise" disabled>RNNoise — недоступен в этой сборке</option>
      <option v-if="deepfilterReleaseEnabled()" value="deepfilter">DeepFilterNet3</option>
      <option v-if="!deepfilterReleaseEnabled() && mode === 'deepfilter'" value="deepfilter" disabled>DeepFilterNet3 — недоступен в этой сборке</option>
    </select>
  </label>
  <p v-if="mode === 'deepfilter' && deepfilterReleaseEnabled()" class="state">Может повысить нагрузку процессора и задержку.</p>
</template>

<style scoped>
@media (max-width: 600px) {
  .audio-processing-row--noise { flex-direction: column; align-items: stretch; gap: 8px; padding: 12px 0; }
  .audio-processing-row--noise select { width: 100%; }
}
</style>
