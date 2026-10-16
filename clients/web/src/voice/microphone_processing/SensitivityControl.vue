<script setup lang="ts">
import { computed } from 'vue'
import { microphoneSettings, microphoneMeter, setMicrophoneSettings } from './runtime'
defineProps<{ vad: boolean }>()
const position = (db: number) => Math.max(0, Math.min(100, (db + 90) / 90 * 100))
const threshold = computed(() => position(microphoneSettings.value.vadThresholdDb))
function change(event: Event) { setMicrophoneSettings({ ...microphoneSettings.value, vadThresholdDb: Number((event.target as HTMLInputElement).value) }) }
</script>
<template>
  <div class="microphone-control">
    <label for="microphone-vad-threshold">Чувствительность <output>{{ microphoneSettings.vadThresholdDb }} dBFS</output></label>
    <input id="microphone-vad-threshold" type="range" min="-70" max="-20" step="1" :value="microphoneSettings.vadThresholdDb" :disabled="!vad" :aria-valuetext="`${microphoneSettings.vadThresholdDb} dBFS`" @input="change">
    <div class="microphone-control-labels"><span>Слышно тихую речь</span><span>Меньше фоновых звуков</span></div>
    <p v-if="!vad">В режиме PTT порог не используется.</p>
    <div class="microphone-level" role="meter" aria-label="Уровень микрофона до усиления" aria-valuemin="-90" aria-valuemax="0" :aria-valuenow="microphoneMeter.levelDb" :aria-valuetext="`${Math.round(microphoneMeter.levelDb)} dBFS`">
      <span :style="{ width: position(microphoneMeter.levelDb) + '%' }" /><i :style="{ left: threshold + '%' }" />
    </div>
    <small>Линия — порог активации. Уровень доступен при включённом микрофоне в звонке.</small>
    <button class="gc-button gc-button--secondary" type="button" @click="setMicrophoneSettings({ ...microphoneSettings, vadThresholdDb: -50 })">Сбросить чувствительность</button>
  </div>
</template>
<style scoped>
.microphone-control { display:grid; gap:8px; margin-block:16px; }
label,.microphone-control-labels { display:flex; justify-content:space-between; gap:12px; }
input { width:100%; } small,.microphone-control-labels { color:var(--text-muted); }
.microphone-level { position:relative; height:10px; border-radius:5px; background:var(--bg-elevated,#20283a); }
.microphone-level span { display:block; height:100%; background:var(--accent,#7084ff); border-radius:5px; }
.microphone-level i { position:absolute; top:-3px; width:2px; height:16px; background:var(--text-primary,#fff); }
button { justify-self:start; }
</style>
