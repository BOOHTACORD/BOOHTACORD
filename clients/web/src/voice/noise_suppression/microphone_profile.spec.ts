import { describe, expect, it } from 'vitest'
import { microphoneConstraints } from '../media_publishing'
import { normalizeAudioProcessing } from './types'
describe('microphone profile boundary', () => {
  it.each(['off', 'browser', 'rnnoise'] as const)('maps %s without leaking preferences into browser constraints', (mode) => {
    expect(microphoneConstraints({ autoGainControl: false, echoCancellation: true, noiseSuppressionMode: mode })).toEqual({
      autoGainControl: false, echoCancellation: true, noiseSuppression: mode === 'browser', channelCount: { ideal: 1 }, sampleRate: { ideal: 48_000 },
    })
  })
  it.each([[true, 'browser'], [false, 'off'], [undefined, 'browser']] as const)('migrates the legacy preference %s', (legacy, expected) => {
    expect(normalizeAudioProcessing({ noiseSuppression: legacy }).noiseSuppressionMode).toBe(expected)
  })
  it('keeps valid preferences and safely rejects unknown modes', () => {
    expect(normalizeAudioProcessing({ noiseSuppressionMode: 'auto' }).noiseSuppressionMode).toBe('auto')
    expect(normalizeAudioProcessing({ noiseSuppressionMode: 'off' }).noiseSuppressionMode).toBe('off')
    expect(normalizeAudioProcessing({ autoGainControl: false, noiseSuppressionMode: 'rnnoise' })).toEqual({ autoGainControl: false, echoCancellation: true, noiseSuppressionMode: 'rnnoise' })
    expect(normalizeAudioProcessing({ noiseSuppressionMode: 'future' }).noiseSuppressionMode).toBe('browser')
  })
})
