import { afterEach, expect, it, vi } from 'vitest'
import { prepareLocalMicrophoneProbe } from './local_microphone_probe'

const mocks = vi.hoisted(() => ({ created: vi.fn(), init: vi.fn(), unmute: vi.fn(), destroy: vi.fn(), output: { enabled: false } }))
vi.mock('./noise_suppression/deepfilter/track_processor', () => ({
  DeepFilterTrackProcessor: class {
    processedTrack = mocks.output
    constructor() { mocks.created() }
    init = mocks.init
    unmute = mocks.unmute
    destroy = mocks.destroy
  },
}))
afterEach(() => { vi.unstubAllGlobals(); vi.unstubAllEnvs(); vi.clearAllMocks() })
const processing = { autoGainControl: false, echoCancellation: true, noiseSuppressionMode: 'deepfilter' } as const
function fixture() {
  let reported = false
  const source = { applyConstraints: vi.fn(async (constraints: MediaTrackConstraints) => { reported = constraints.noiseSuppression === true }), getSettings: () => ({ noiseSuppression: reported }) }
  const stream = { getAudioTracks: () => [source] } as unknown as MediaStream
  vi.stubGlobal('MediaStream', class { constructor(public tracks: unknown[]) {} })
  return { source, stream, context: {} as AudioContext }
}

it('reports browser fallback for a disabled DeepFilter build during a local check', async () => {
  vi.stubEnv('VITE_DEEPFILTER_ENABLED', 'false')
  const f = fixture(), probe = await prepareLocalMicrophoneProbe(f.stream, f.context, processing)
  expect(mocks.created).not.toHaveBeenCalled()
  expect(f.source.applyConstraints).toHaveBeenCalledWith({ autoGainControl: false, echoCancellation: true, noiseSuppression: true })
  expect(probe.state()).toMatchObject({ requestedMode: 'deepfilter', effectiveMode: 'browser', status: 'fallback', fallbackReason: 'release-disabled' })
  await probe.destroy()
})

it('falls back when capture does not confirm browser suppression is disabled', async () => {
  vi.stubEnv('VITE_DEEPFILTER_ENABLED', 'true')
  const f = fixture(); f.source.getSettings = () => ({ noiseSuppression: true })
  const probe = await prepareLocalMicrophoneProbe(f.stream, f.context, processing)
  expect(mocks.created).not.toHaveBeenCalled()
  expect(probe.state()).toMatchObject({ effectiveMode: 'browser', status: 'fallback', fallbackReason: 'unsupported' })
})

it('uses the DeepFilter output for a local check only when explicitly enabled', async () => {
  vi.stubEnv('VITE_DEEPFILTER_ENABLED', 'true')
  const f = fixture(), probe = await prepareLocalMicrophoneProbe(f.stream, f.context, processing)
  expect(mocks.created).toHaveBeenCalledOnce(); expect(mocks.unmute).toHaveBeenCalledOnce()
  expect(probe.state()).toMatchObject({ requestedMode: 'deepfilter', effectiveMode: 'deepfilter', status: 'active' })
  expect((probe.stream as unknown as { tracks: unknown[] }).tracks).toEqual([mocks.output])
  await probe.destroy(); expect(mocks.destroy).toHaveBeenCalledOnce()
})

it('cleans up a failed processor and reports the confirmed browser fallback', async () => {
  vi.stubEnv('VITE_DEEPFILTER_ENABLED', 'true')
  mocks.init.mockRejectedValueOnce(new Error('unavailable'))
  const f = fixture(), probe = await prepareLocalMicrophoneProbe(f.stream, f.context, processing)
  expect(mocks.destroy).toHaveBeenCalledOnce()
  expect(f.source.applyConstraints).toHaveBeenCalledWith({ autoGainControl: false, echoCancellation: true, noiseSuppression: true })
  expect(probe.state()).toMatchObject({ requestedMode: 'deepfilter', effectiveMode: 'browser', status: 'fallback', fallbackReason: 'processor-error' })
})
