<script setup lang="ts">
import { audioProcessingStatus, noiseSuppressionModeLabel, type AudioProcessingDiagnostics } from './audio_processing_diagnostics'
import type { AudioProcessingOptions } from './livekit_gateway'
import { rnnoiseReleaseEnabled } from './noise_suppression/capabilities'
import type { NoiseSuppressionMode } from './noise_suppression/types'
import StreamStartSoundSetting from './StreamStartSoundSetting.vue'
defineProps<{ processing: AudioProcessingOptions; diagnostics: AudioProcessingDiagnostics }>()
const emit = defineEmits<{ setProcessing: [processing: AudioProcessingOptions] }>()
</script>
<template>
  <details class="audio-processing-details">
    <summary>Режим и диагностика обработки</summary>
    <StreamStartSoundSetting />
    <label>Режим шумоподавления<select class="gc-field" :value="processing.noiseSuppressionMode" @change="emit('setProcessing', { ...processing, noiseSuppressionMode: ($event.target as HTMLSelectElement).value as NoiseSuppressionMode })">
      <option value="off">Выключено</option><option value="browser">Стандартное — браузер</option>
      <option v-if="rnnoiseReleaseEnabled()" value="rnnoise">RNNoise — экспериментальное</option>
      <option v-if="!rnnoiseReleaseEnabled() && processing.noiseSuppressionMode === 'rnnoise'" value="rnnoise" disabled>RNNoise — недоступен в этой сборке</option>
    </select></label>
    <dl class="audio-processing-values">
      <dt>Автоматическая громкость</dt><dd>{{ audioProcessingStatus(diagnostics.autoGainControl) }}</dd>
      <dt>Подавление эха</dt><dd>{{ audioProcessingStatus(diagnostics.echoCancellation) }}</dd>
      <dt>Действующий фильтр</dt><dd>{{ noiseSuppressionModeLabel(diagnostics.noiseSuppressionRuntime.effectiveMode) }}</dd>
      <dt>Browser NS</dt><dd>{{ audioProcessingStatus(diagnostics.noiseSuppression) }}</dd>
      <dt>Источник capture</dt><dd>{{ diagnostics.captureSource === 'original-microphone' ? 'исходный микрофон' : 'недоступен' }}</dd>
      <dt>Статус фильтра</dt><dd>{{ diagnostics.noiseSuppressionRuntime.status }}</dd>
      <template v-if="diagnostics.noiseSuppressionRuntime.modelId"><dt>Модель</dt><dd>{{ diagnostics.noiseSuppressionRuntime.modelId }}</dd></template>
      <dt>Частота capture</dt><dd>{{ diagnostics.noiseSuppressionRuntime.captureSampleRate === undefined ? 'недоступна' : `${diagnostics.noiseSuppressionRuntime.captureSampleRate} Гц` }}</dd>
      <template v-if="diagnostics.noiseSuppressionRuntime.initDurationMs !== undefined"><dt>Подготовка фильтра</dt><dd>{{ diagnostics.noiseSuppressionRuntime.initDurationMs.toFixed(1) }} мс</dd></template>
      <template v-if="diagnostics.noiseSuppressionRuntime.contextSampleRate"><dt>AudioContext</dt><dd>{{ diagnostics.noiseSuppressionRuntime.contextSampleRate }} Гц</dd></template>
      <template v-if="diagnostics.noiseSuppressionRuntime.processedFrames !== undefined"><dt>Кадры / ошибки</dt><dd>{{ diagnostics.noiseSuppressionRuntime.processedFrames }} / {{ diagnostics.noiseSuppressionRuntime.processorErrors ?? 0 }}</dd></template>
    </dl>
  </details>
</template>
