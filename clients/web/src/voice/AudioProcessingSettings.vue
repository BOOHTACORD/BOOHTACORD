<script setup lang="ts">
import { computed } from 'vue'
import type { AudioProcessingDiagnostics } from './audio_processing_diagnostics'
import type { AudioProcessingOptions, NoiseSuppressionMode } from './noise_suppression/types'
import { noiseSuppressionStatus } from './noise_suppression_status'
import GainControl from './microphone_processing/GainControl.vue'
import NoiseSuppressionSelect from './NoiseSuppressionSelect.vue'
import StreamStartSoundSetting from './StreamStartSoundSetting.vue'

const props = defineProps<{ processing: AudioProcessingOptions; diagnostics: AudioProcessingDiagnostics }>()
const emit = defineEmits<{ setProcessing: [processing: AudioProcessingOptions] }>()
const status = computed(() => noiseSuppressionStatus(props.processing.noiseSuppressionMode, props.diagnostics.noiseSuppressionRuntime))
function setProcessing(key: 'autoGainControl' | 'echoCancellation', event: Event): void {
  emit('setProcessing', { ...props.processing, [key]: (event.target as HTMLInputElement).checked })
}
function setMode(mode: NoiseSuppressionMode): void { emit('setProcessing', { ...props.processing, noiseSuppressionMode: mode }) }
</script>

<template>
  <section class="audio-processing-section" aria-labelledby="audio-processing-title"><h2 id="audio-processing-title">Обработка микрофона</h2>
    <GainControl :agc="processing.autoGainControl" :show-clipping="false" />
    <NoiseSuppressionSelect :mode="processing.noiseSuppressionMode" @change="setMode" />
    <label class="audio-processing-row"><span>Подавление эха<small>Убирает обратный звук из динамиков</small></span><input type="checkbox" role="switch" :checked="processing.echoCancellation" @change="setProcessing('echoCancellation', $event)"></label>
    <label class="audio-processing-row"><span>Автоматическая громкость<small>Выравнивает уровень микрофона</small></span><input type="checkbox" role="switch" :checked="processing.autoGainControl" @change="setProcessing('autoGainControl', $event)"></label>
    <StreamStartSoundSetting />
    <p v-if="status" :class="diagnostics.noiseSuppressionRuntime.status === 'error' ? 'state-error' : 'state'" :role="diagnostics.noiseSuppressionRuntime.status === 'error' ? 'alert' : 'status'">{{ status }}</p>
  </section>
</template>
