<script setup lang="ts">
import { microphoneSettings, microphoneMeter, setMicrophoneSettings } from './runtime'
defineProps<{ agc: boolean }>()
function change(event: Event) { setMicrophoneSettings({ ...microphoneSettings.value, microphoneGainPercent: Number((event.target as HTMLInputElement).value) }) }
</script>
<template>
  <div class="microphone-gain">
    <label for="microphone-input-gain">Громкость микрофона <output>{{ agc ? '100' : microphoneSettings.microphoneGainPercent }}%</output></label>
    <input id="microphone-input-gain" type="range" min="0" max="200" step="1" :disabled="agc" :value="microphoneSettings.microphoneGainPercent" :aria-valuetext="agc ? 'Управляется автоматически' : `${microphoneSettings.microphoneGainPercent}%`" @input="change">
    <p v-if="agc">Управляется автоматически. Ручное значение сохранено: {{ microphoneSettings.microphoneGainPercent }}%.</p>
    <p v-else>Усиление отправляемого сигнала. 100% — без дополнительного усиления.</p>
    <p role="status">{{ microphoneMeter.clipping ? 'Перегрузка: уменьшите громкость микрофона.' : 'Перегрузка не обнаружена.' }}</p>
    <button class="gc-button gc-button--secondary" type="button" :disabled="agc" @click="setMicrophoneSettings({ ...microphoneSettings, microphoneGainPercent: 100 })">Сбросить громкость</button>
  </div>
</template>
<style scoped>
.microphone-gain { display:grid; gap:8px; margin-block:16px; }
label { display:flex; justify-content:space-between; gap:12px; } input { width:100%; }
</style>
