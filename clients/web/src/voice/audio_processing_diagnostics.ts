import type { NoiseSuppressionRuntimeState } from './noise_suppression/types'
import type { RnnoiseCounters } from './noise_suppression/diagnostics'
import type { AudioProcessingOptions } from './media_publishing'

export type AudioProcessingReport = 'ENABLED' | 'DISABLED' | 'UNAVAILABLE'

export interface BrowserAudioProcessingSettings {
  sampleRate?: number
  channelCount?: number
  autoGainControl?: boolean
  echoCancellation?: boolean
  noiseSuppression?: boolean
}

export interface AudioProcessingDiagnostic {
  reported: AudioProcessingReport
  requested: boolean
}

export interface AudioProcessingDiagnostics {
  autoGainControl: AudioProcessingDiagnostic
  echoCancellation: AudioProcessingDiagnostic
  noiseSuppression: AudioProcessingDiagnostic
  captureSource: 'original-microphone' | 'unavailable'
  noiseSuppressionRuntime: NoiseSuppressionRuntimeState & Partial<RnnoiseCounters>
}

function report(value: boolean | undefined): AudioProcessingReport {
  return value === undefined ? 'UNAVAILABLE' : value ? 'ENABLED' : 'DISABLED'
}

export function describeAudioProcessing(requested: AudioProcessingOptions, settings?: BrowserAudioProcessingSettings, runtime?: NoiseSuppressionRuntimeState): AudioProcessingDiagnostics {
  return {
    captureSource: settings ? 'original-microphone' : 'unavailable',
    noiseSuppressionRuntime: runtime ?? { requestedMode: requested.noiseSuppressionMode, effectiveMode: 'unknown', status: 'idle' },
    autoGainControl: { requested: requested.autoGainControl, reported: report(settings?.autoGainControl) },
    echoCancellation: { requested: requested.echoCancellation, reported: report(settings?.echoCancellation) },
    noiseSuppression: { requested: requested.noiseSuppressionMode === 'browser', reported: report(settings?.noiseSuppression) },
  }
}

export function audioProcessingStatus(diagnostic: AudioProcessingDiagnostic): string {
  const requested = diagnostic.requested ? 'включено' : 'выключено'
  if (diagnostic.reported === 'UNAVAILABLE') return `Запрошено: ${requested}; браузер не сообщил состояние.`
  return `Запрошено: ${requested}; браузер сообщает: ${diagnostic.reported === 'ENABLED' ? 'включено' : 'выключено'}.`
}

export function noiseSuppressionModeLabel(mode: NoiseSuppressionRuntimeState['effectiveMode']): string {
  return mode === 'rnnoise' ? 'RNNoise' : mode === 'deepfilter' ? 'DeepFilterNet3' : mode === 'browser' ? 'Стандартное — браузер' : mode === 'off' ? 'Выключено' : 'Неизвестно'
}
export function noiseSuppressionFallbackLabel(reason?: NoiseSuppressionRuntimeState['fallbackReason']): string {
  const labels = { 'release-disabled': 'Фильтр отключён в этой сборке', unsupported: 'Браузер не поддерживает фильтр', 'sample-rate': 'Частота AudioContext отличается от 48 кГц', 'asset-load': 'Фильтр не удалось загрузить', 'init-timeout': 'Превышено время подготовки фильтра', 'processor-error': 'Ошибка аудиопроцессора', overload: 'Аудиопроцессор перегружен' }
  return reason ? labels[reason] : ''
}
