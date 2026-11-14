import { afterEach, expect, it, vi } from 'vitest'
import type { AudioProcessingOptions } from '../types'
import * as capabilities from '../capabilities'
import { fixture } from './test_fixture'

afterEach(() => { vi.unstubAllEnvs(); vi.restoreAllMocks() })
const options = { autoGainControl: false, echoCancellation: true, noiseSuppressionMode: 'deepfilter' } as unknown as AudioProcessingOptions

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
