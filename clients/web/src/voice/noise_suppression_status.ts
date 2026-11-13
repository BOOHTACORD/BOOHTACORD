import { noiseSuppressionFallbackLabel } from './audio_processing_diagnostics'
import type { NoiseSuppressionMode, NoiseSuppressionRuntimeState } from './noise_suppression/types'

export function noiseSuppressionStatus(mode: NoiseSuppressionMode, runtime: NoiseSuppressionRuntimeState): string {
  if (runtime.status === 'error') return 'Обработка микрофона остановлена. Отправка звука выключена.'
  if ((mode !== 'rnnoise' && mode !== 'deepfilter') || runtime.requestedMode !== mode) return ''
  const name = mode === 'rnnoise' ? 'RNNoise' : 'DeepFilterNet3'
  return {
    idle: '', initializing: `Проверяем работу ${name}…`, active: `${name} активен.`,
    fallback: runtime.effectiveMode === 'browser'
      ? `Включена стандартная обработка${noiseSuppressionFallbackLabel(runtime.fallbackReason) ? `: ${noiseSuppressionFallbackLabel(runtime.fallbackReason).toLowerCase()}` : ''}.`
      : 'Резервный режим не подтверждён.',
    unsupported: `${name} недоступен на этом устройстве.`, error: '',
  }[runtime.status]
}
