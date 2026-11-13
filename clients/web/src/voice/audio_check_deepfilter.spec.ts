import { expect, it, vi } from 'vitest'
import { startMicrophoneCheck } from './audio_check'

const mocks = vi.hoisted(() => ({ prepare: vi.fn() }))
vi.mock('./local_deepfilter_probe', () => ({ prepareLocalDeepFilterProbe: mocks.prepare }))

it('measures the derived DeepFilter track and releases it after the local check', async () => {
  const source = { stop: vi.fn(), addEventListener: vi.fn(), removeEventListener: vi.fn() }
  const input = { getTracks: () => [source], getAudioTracks: () => [source] }
  const derived = { getTracks: () => [] }, destroy = vi.fn(async () => {})
  mocks.prepare.mockResolvedValue({ stream: derived, destroy, state: () => ({ requestedMode: 'deepfilter', effectiveMode: 'deepfilter', status: 'active' }) })
  const makeSource = vi.fn(() => ({ connect: vi.fn(), disconnect: vi.fn() }))
  const context = { createMediaStreamSource: makeSource, createAnalyser: () => ({ fftSize: 0 }), close: vi.fn(async () => {}) } as unknown as AudioContext
  const getUserMedia = vi.fn(async () => input as unknown as MediaStream)
  const check = await startMicrophoneCheck('default', { getUserMedia }, () => context,
    { processing: { autoGainControl: false, echoCancellation: true, noiseSuppressionMode: 'deepfilter' } })
  expect(mocks.prepare).toHaveBeenCalledOnce(); expect(makeSource).toHaveBeenCalledWith(derived)
  expect(check.processingState?.()).toMatchObject({ effectiveMode: 'deepfilter', status: 'active' })
  await check.stop(); expect(destroy).toHaveBeenCalledOnce(); expect(source.stop).toHaveBeenCalledOnce()
})
