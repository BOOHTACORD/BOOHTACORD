import { afterEach, expect, it, vi } from 'vitest'
import type { AudioProcessingOptions } from '../types'
import * as capabilities from '../capabilities'
import type { LocalAudioTrack } from 'livekit-client'
import { LiveKitMicrophoneAdapter } from './controller'

afterEach(() => { vi.unstubAllEnvs(); vi.restoreAllMocks() })
const options = { autoGainControl: false, echoCancellation: true, noiseSuppressionMode: 'deepfilter' } as unknown as AudioProcessingOptions

function fixture() {
  let reported = true
  const source = { enabled: true, stop: vi.fn(), getSettings: () => ({ noiseSuppression: reported }) }
  const output = { enabled: true }
  const processor = { processedTrack: output, name: 'test', mute: vi.fn(() => { output.enabled = false }), unmute: vi.fn(), destroy: vi.fn(), init: vi.fn() }
  const track = { mediaStreamTrack: source, mute: vi.fn(async () => { source.enabled = false }),
    unmute: vi.fn(async () => { source.enabled = true }), stop: vi.fn(),
    applyConstraints: vi.fn(async (constraints: MediaTrackConstraints) => { reported = constraints.noiseSuppression === true }), restartTrack: vi.fn(async () => {}),
    setProcessor: vi.fn(async () => { track.mediaStreamTrack = output as typeof source }),
    stopProcessor: vi.fn(async () => { track.mediaStreamTrack = source }) }
  const dependencies = { createTrack: vi.fn(async () => track as unknown as LocalAudioTrack),
    publishTrack: vi.fn(async () => {}), unpublishTrack: vi.fn(async () => {}),
    createProcessor: vi.fn((_callbacks: unknown, _options?: AudioProcessingOptions) => processor as never) }
  return { adapter: new LiveKitMicrophoneAdapter(dependencies), dependencies, track, processor, source, output }
}

it('keeps Auto requested while using browser fallback without experimental v0.2', async () => {
  vi.stubEnv('VITE_RNNOISE_V02_ENABLED', 'false')
  const f = fixture()
  await f.adapter.setEnabled(true, { ...options, noiseSuppressionMode: 'auto' } as AudioProcessingOptions)
  expect(f.dependencies.createProcessor).not.toHaveBeenCalled()
  expect(f.adapter.runtimeState).toMatchObject({ requestedMode: 'auto', effectiveMode: 'browser', status: 'active' })
  await f.adapter.dispose()
})

it('fails muted when Auto cannot confirm browser suppression', async () => {
  vi.stubEnv('VITE_RNNOISE_V02_ENABLED', 'false')
  const f = fixture()
  f.source.getSettings = () => ({}) as never
  await expect(f.adapter.setEnabled(true, { ...options, noiseSuppressionMode: 'auto' } as AudioProcessingOptions)).rejects.toThrow('Браузер не подтвердил')
  expect(f.dependencies.publishTrack).not.toHaveBeenCalled()
  expect(f.source.enabled).toBe(false)
})

it('selects the research RNNoise backend while retaining the Auto request', async () => {
  vi.stubEnv('VITE_RNNOISE_V02_ENABLED', 'true')
  vi.stubEnv('VITE_RNNOISE_ENABLED', 'true')
  vi.spyOn(capabilities, 'supportsRnnoise').mockReturnValue(true)
  const f = fixture()
  await f.adapter.setEnabled(true, { ...options, noiseSuppressionMode: 'auto' } as AudioProcessingOptions)
  expect(f.dependencies.createProcessor.mock.calls[0][1]?.noiseSuppressionMode).toBe('rnnoise')
  expect(f.adapter.runtimeState).toMatchObject({ requestedMode: 'auto', effectiveMode: 'rnnoise', status: 'active' })
  await f.adapter.dispose()
})

it('retains Auto and falls back safely when research initialization fails', async () => {
  vi.stubEnv('VITE_RNNOISE_V02_ENABLED', 'true')
  vi.stubEnv('VITE_RNNOISE_ENABLED', 'true')
  vi.spyOn(capabilities, 'supportsRnnoise').mockReturnValue(true)
  const f = fixture()
  f.track.setProcessor.mockRejectedValueOnce(new Error('unavailable'))
  await f.adapter.setEnabled(true, { ...options, noiseSuppressionMode: 'auto' } as AudioProcessingOptions)
  expect(f.adapter.runtimeState).toMatchObject({ requestedMode: 'auto', effectiveMode: 'browser', status: 'fallback' })
  expect(f.track.applyConstraints).toHaveBeenLastCalledWith({ autoGainControl: false, echoCancellation: true, noiseSuppression: true })
  await f.adapter.dispose()
})

it('uses explicitly opted-in DeepFilter for Auto and safely falls back on failure', async () => {
  vi.stubEnv('VITE_AUTO_DEEPFILTER_RESEARCH', 'true')
  vi.stubEnv('VITE_DEEPFILTER_ENABLED', 'true')
  vi.spyOn(capabilities, 'supportsRnnoise').mockReturnValue(true)
  const f = fixture()
  const auto = { ...options, noiseSuppressionMode: 'auto' } as AudioProcessingOptions
  await f.adapter.setEnabled(true, auto)
  expect(f.dependencies.createProcessor.mock.calls[0][1]?.noiseSuppressionMode).toBe('deepfilter')
  expect(f.adapter.runtimeState).toMatchObject({ requestedMode: 'auto', effectiveMode: 'deepfilter', status: 'active' })
  await f.adapter.dispose()

  const failed = fixture()
  failed.track.setProcessor.mockRejectedValueOnce(new Error('unavailable'))
  await failed.adapter.setEnabled(true, auto)
  expect(failed.adapter.runtimeState).toMatchObject({ requestedMode: 'auto', effectiveMode: 'browser', status: 'fallback' })
  await failed.adapter.dispose()
})

it('never enables research DeepFilter Auto in a production build', async () => {
  vi.stubEnv('DEV', false)
  vi.stubEnv('VITE_AUTO_DEEPFILTER_RESEARCH', 'true')
  vi.stubEnv('VITE_DEEPFILTER_ENABLED', 'true')
  vi.stubEnv('VITE_RNNOISE_V02_ENABLED', 'false')
  vi.spyOn(capabilities, 'supportsRnnoise').mockReturnValue(true)
  const f = fixture()
  await f.adapter.setEnabled(true, { ...options, noiseSuppressionMode: 'auto' } as AudioProcessingOptions)
  expect(f.dependencies.createProcessor).not.toHaveBeenCalled()
  expect(f.adapter.runtimeState).toMatchObject({ requestedMode: 'auto', effectiveMode: 'browser' })
  await f.adapter.dispose()
})

it('never promotes explicit off to an automatic engine', async () => {
  vi.stubEnv('VITE_RNNOISE_V02_ENABLED', 'true')
  vi.spyOn(capabilities, 'supportsRnnoise').mockReturnValue(true)
  const f = fixture()
  await f.adapter.setEnabled(true, { ...options, noiseSuppressionMode: 'off' } as AudioProcessingOptions)
  expect(f.dependencies.createProcessor).not.toHaveBeenCalled()
  expect(f.adapter.runtimeState).toMatchObject({ requestedMode: 'off', effectiveMode: 'off', status: 'active' })
  await f.adapter.dispose()
})

it('transitions between browser Auto and explicit off without creating a model', async () => {
  vi.stubEnv('VITE_RNNOISE_V02_ENABLED', 'false')
  const f = fixture()
  const auto = { ...options, noiseSuppressionMode: 'auto' } as AudioProcessingOptions
  const off = { ...options, noiseSuppressionMode: 'off' } as AudioProcessingOptions
  await f.adapter.setEnabled(true, auto)
  await f.adapter.setProcessing(off)
  expect(f.adapter.runtimeState).toMatchObject({ requestedMode: 'off', effectiveMode: 'off', status: 'active' })
  await f.adapter.setProcessing(auto)
  expect(f.adapter.runtimeState).toMatchObject({ requestedMode: 'auto', effectiveMode: 'browser', status: 'active' })
  expect(f.dependencies.createProcessor).not.toHaveBeenCalled()
  await f.adapter.dispose()
})
