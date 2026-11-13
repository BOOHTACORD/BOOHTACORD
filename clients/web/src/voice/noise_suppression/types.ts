/** Preferences stay independent of the browser capture constraint contract. */
export type NoiseSuppressionMode = 'off' | 'browser' | 'rnnoise' | 'deepfilter'
export interface AudioProcessingOptions {
  autoGainControl: boolean
  echoCancellation: boolean
  noiseSuppressionMode: NoiseSuppressionMode
}
export interface BrowserAudioProcessingConstraints {
  autoGainControl: boolean
  echoCancellation: boolean
  noiseSuppression: boolean
}
export type NoiseSuppressionFallbackReason = 'unsupported' | 'sample-rate' | 'asset-load' | 'init-timeout' | 'processor-error' | 'overload' | 'release-disabled'
export interface NoiseSuppressionRuntimeState {
  requestedMode: NoiseSuppressionMode
  effectiveMode: NoiseSuppressionMode | 'unknown'
  status: 'idle' | 'initializing' | 'active' | 'fallback' | 'unsupported' | 'error'
  fallbackReason?: NoiseSuppressionFallbackReason
  modelId?: string
  contextSampleRate?: number
  captureSampleRate?: number
  initDurationMs?: number
}
export function normalizeAudioProcessing(value: unknown): AudioProcessingOptions {
  const stored = value && typeof value === 'object' ? value as Record<string, unknown> : {}
  const mode = stored.noiseSuppressionMode
  return {
    autoGainControl: typeof stored.autoGainControl === 'boolean' ? stored.autoGainControl : true,
    echoCancellation: typeof stored.echoCancellation === 'boolean' ? stored.echoCancellation : true,
    noiseSuppressionMode: mode === 'off' || mode === 'browser' || mode === 'rnnoise' || mode === 'deepfilter'
      ? mode : stored.noiseSuppression === false ? 'off' : 'browser',
  }
}
export function browserProcessingConstraints(options: AudioProcessingOptions): BrowserAudioProcessingConstraints {
  return { autoGainControl: options.autoGainControl, echoCancellation: options.echoCancellation, noiseSuppression: options.noiseSuppressionMode === 'browser' }
}
