import { expect, it, vi } from 'vitest'
import type { LocalAudioTrack } from 'livekit-client'
import { LiveKitMicrophoneAdapter } from './controller'
import type { NoiseSuppressionRuntimeState } from '../types'

it('retains the missing-asset reason while restoring the standard engine', async () => {
  const source = { enabled: true, stop: vi.fn(), getSettings: () => ({ noiseSuppression: true }) }
  let callbacks!: { onState: (state: NoiseSuppressionRuntimeState) => void; onFailure: (reason: 'asset-load') => void }
  const processor = { processedTrack: undefined, mute: vi.fn(), destroy: vi.fn(), name: 'test' }
  const track = {
    mediaStreamTrack: source,
    mute: vi.fn(async () => { source.enabled = false }),
    unmute: vi.fn(async () => { source.enabled = true }),
    stop: vi.fn(), applyConstraints: vi.fn(async () => undefined),
    stopProcessor: vi.fn(async () => undefined),
    setProcessor: vi.fn(async () => {
      callbacks.onState({ requestedMode: 'rnnoise', effectiveMode: 'unknown', status: 'error', fallbackReason: 'asset-load' })
      callbacks.onFailure('asset-load')
      throw new Error('RNNoise manifest unavailable')
    }),
  }
  const adapter = new LiveKitMicrophoneAdapter({
    createTrack: vi.fn(async () => track as unknown as LocalAudioTrack),
    publishTrack: vi.fn(async () => undefined), unpublishTrack: vi.fn(async () => undefined),
    isReconnecting: () => false,
    createProcessor: value => { callbacks = value; return processor as never },
  })
  await adapter.setEnabled(true, { noiseSuppressionMode: 'rnnoise', autoGainControl: false, echoCancellation: true })
  expect(adapter.runtimeState).toMatchObject({ requestedMode: 'rnnoise', effectiveMode: 'browser',
    status: 'fallback', fallbackReason: 'asset-load' })
  expect(track.applyConstraints).toHaveBeenLastCalledWith({ noiseSuppression: true, autoGainControl: false, echoCancellation: true })
  await adapter.dispose()
})
