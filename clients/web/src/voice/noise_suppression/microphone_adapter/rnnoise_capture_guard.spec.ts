import { afterEach, expect, it, vi } from 'vitest'
import type { LocalAudioTrack } from 'livekit-client'
import { LiveKitMicrophoneAdapter } from './controller'

afterEach(() => { vi.unstubAllEnvs(); vi.restoreAllMocks() })

const options = { noiseSuppressionMode: 'rnnoise', autoGainControl: false, echoCancellation: true } as const

function fixture(reported: boolean | undefined) {
  const source = { enabled: true, stop: vi.fn(), getSettings: () => ({ noiseSuppression: reported }) }
  const track = {
    mediaStreamTrack: source, mute: vi.fn(async () => { source.enabled = false }),
    unmute: vi.fn(async () => { source.enabled = true }), stop: vi.fn(),
    applyConstraints: vi.fn(async () => undefined), stopProcessor: vi.fn(async () => undefined),
    setProcessor: vi.fn(async () => undefined),
  }
  const dependencies = {
    createTrack: vi.fn(async () => track as unknown as LocalAudioTrack),
    publishTrack: vi.fn(async () => undefined), unpublishTrack: vi.fn(async () => undefined),
    createProcessor: vi.fn((_callbacks: { onFailure(reason: 'overload'): void }) =>
      ({ mute: vi.fn(), unmute: vi.fn(), destroy: vi.fn(), processedTrack: source }) as never),
  }
  return { adapter: new LiveKitMicrophoneAdapter(dependencies), dependencies, track }
}

it('falls back without stacking RNNoise when browser NS remains enabled', async () => {
  vi.stubEnv('VITE_RNNOISE_ENABLED', 'true')
  const f = fixture(true)
  await f.adapter.setEnabled(true, options)
  expect(f.dependencies.createProcessor).not.toHaveBeenCalled()
  expect(f.adapter.runtimeState).toMatchObject({
    requestedMode: 'rnnoise', effectiveMode: 'browser',
    status: 'fallback', fallbackReason: 'unsupported',
  })
  expect(f.track.applyConstraints).toHaveBeenLastCalledWith({
    noiseSuppression: true, autoGainControl: false, echoCancellation: true,
  })
  await f.adapter.dispose()
})

it('falls back when disabling browser NS is rejected', async () => {
  vi.stubEnv('VITE_RNNOISE_ENABLED', 'true')
  const f = fixture(true)
  f.track.applyConstraints.mockRejectedValueOnce(new Error('constraint rejected'))
  await f.adapter.setEnabled(true, options)
  expect(f.dependencies.createProcessor).not.toHaveBeenCalled()
  expect(f.adapter.runtimeState).toMatchObject({ requestedMode: 'rnnoise', effectiveMode: 'browser', status: 'fallback', fallbackReason: 'unsupported' })
  expect(f.dependencies.publishTrack).toHaveBeenCalledOnce()
  await f.adapter.dispose()
})

it('does not publish when neither the disabled model constraint nor fallback can be confirmed', async () => {
  vi.stubEnv('VITE_RNNOISE_ENABLED', 'true')
  const f = fixture(undefined)
  await expect(f.adapter.setEnabled(true, options)).rejects.toThrow()
  expect(f.dependencies.createProcessor).not.toHaveBeenCalled()
  expect(f.dependencies.publishTrack).not.toHaveBeenCalled()
  expect(f.track.mediaStreamTrack.enabled).toBe(false)
  await f.adapter.dispose()
})

it('attaches RNNoise when browser suppression is confirmed off', async () => {
  vi.stubEnv('VITE_RNNOISE_ENABLED', 'true')
  const f = fixture(false)
  await f.adapter.setEnabled(true, options)
  expect(f.dependencies.createProcessor).toHaveBeenCalledOnce()
  expect(f.adapter.runtimeState).toMatchObject({ requestedMode: 'rnnoise', effectiveMode: 'rnnoise', status: 'active' })
  await f.adapter.dispose()
})

it('mutes a published track when processor recovery cannot confirm browser NS', async () => {
  vi.stubEnv('VITE_RNNOISE_ENABLED', 'true')
  const f = fixture(false)
  await f.adapter.setEnabled(true, options)
  const callbacks = f.dependencies.createProcessor.mock.calls[0][0]
  callbacks.onFailure('overload')
  await vi.waitFor(() => expect(f.adapter.runtimeState.status).toBe('error'))
  expect(f.track.mediaStreamTrack.enabled).toBe(false)
  expect(f.adapter.runtimeState).toMatchObject({ effectiveMode: 'unknown', fallbackReason: 'overload' })
  await f.adapter.dispose()
})
