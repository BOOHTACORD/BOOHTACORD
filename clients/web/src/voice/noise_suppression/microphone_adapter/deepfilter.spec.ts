import { afterEach, expect, it, vi } from 'vitest'
import type { AudioProcessingOptions } from '../types'
import { fixture } from '../../../../tests/audio/noise_adapter_fixture'

afterEach(() => { vi.unstubAllEnvs(); vi.restoreAllMocks() })
const options = { autoGainControl: false, echoCancellation: true, noiseSuppressionMode: 'deepfilter' } as unknown as AudioProcessingOptions

it('keeps DeepFilter preference but uses browser fallback when its build flag is disabled', async () => {
  vi.stubEnv('VITE_DEEPFILTER_ENABLED', 'false')
  const f = fixture(); await f.adapter.setEnabled(true, options)
  expect(f.dependencies.createProcessor).not.toHaveBeenCalled()
  expect(f.track.applyConstraints).toHaveBeenLastCalledWith({ autoGainControl: false, echoCancellation: true, noiseSuppression: true })
  expect(f.adapter.runtimeState).toMatchObject({ requestedMode: 'deepfilter', effectiveMode: 'browser', status: 'fallback', fallbackReason: 'release-disabled' })
  await f.adapter.dispose()
})

it('does not stack DeepFilter on browser suppression when disable is ignored', async () => {
  vi.stubEnv('VITE_DEEPFILTER_ENABLED', 'true')
  const f = fixture(); f.track.applyConstraints.mockImplementation(async () => {})
  await f.adapter.setEnabled(true, options)
  expect(f.dependencies.createProcessor).not.toHaveBeenCalled()
  expect(f.adapter.runtimeState).toMatchObject({ requestedMode: 'deepfilter', effectiveMode: 'browser', status: 'fallback', fallbackReason: 'unsupported' })
  await f.adapter.dispose()
})

it('does not publish when DeepFilter and browser NS settings cannot be confirmed', async () => {
  vi.stubEnv('VITE_DEEPFILTER_ENABLED', 'true')
  const f = fixture(); f.source.getSettings = () => ({}) as never
  await expect(f.adapter.setEnabled(true, options)).rejects.toThrow('Браузер не подтвердил')
  expect(f.dependencies.createProcessor).not.toHaveBeenCalled()
  expect(f.dependencies.publishTrack).not.toHaveBeenCalled()
  expect(f.source.enabled).toBe(false)
  expect(f.adapter.runtimeState).toMatchObject({ requestedMode: 'deepfilter', effectiveMode: 'unknown', status: 'error' })
  await f.adapter.dispose()
})

it('attaches the requested DeepFilter processor before publishing when explicitly enabled', async () => {
  vi.stubEnv('VITE_DEEPFILTER_ENABLED', 'true')
  const f = fixture(); await f.adapter.setEnabled(true, options)
  expect(f.dependencies.createProcessor).toHaveBeenCalledOnce()
  expect(f.dependencies.createProcessor.mock.calls[0][1]).toEqual(options)
  expect(f.track.applyConstraints).toHaveBeenCalledWith({ autoGainControl: false, echoCancellation: true, noiseSuppression: false })
  expect(f.adapter.runtimeState).toMatchObject({ requestedMode: 'deepfilter', effectiveMode: 'deepfilter', status: 'active' })
  expect(f.processor.mute).toHaveBeenCalled()
  await f.adapter.setEnabled(false, options)
  expect(f.output.enabled).toBe(false)
  await f.adapter.dispose()
})

it('keeps the microphone muted if both DeepFilter and fallback fail', async () => {
  vi.stubEnv('VITE_DEEPFILTER_ENABLED', 'true')
  const f = fixture()
  f.track.setProcessor.mockRejectedValueOnce(new Error('processor unavailable'))
  f.track.applyConstraints.mockImplementationOnce(async () => { f.source.getSettings = () => ({ noiseSuppression: false }) })
    .mockRejectedValueOnce(new Error('fallback unavailable'))
  await expect(f.adapter.setEnabled(true, options)).rejects.toThrow('fallback unavailable')
  expect(f.source.enabled).toBe(false); expect(f.output.enabled).toBe(false)
  expect(f.dependencies.publishTrack).not.toHaveBeenCalled()
})

it('preserves the reported asset failure when initialization falls back', async () => {
  vi.stubEnv('VITE_DEEPFILTER_ENABLED', 'true')
  const f = fixture()
  f.track.setProcessor.mockImplementationOnce(async () => {
    const callbacks = f.dependencies.createProcessor.mock.calls[0][0] as { onFailure: (reason: string) => void }
    callbacks.onFailure('asset-load')
    throw new Error('unavailable')
  })
  await f.adapter.setEnabled(true, options)
  expect(f.adapter.runtimeState).toMatchObject({ requestedMode: 'deepfilter', effectiveMode: 'browser', status: 'fallback', fallbackReason: 'asset-load' })
  await f.adapter.dispose()
})
