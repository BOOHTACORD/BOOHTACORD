import { afterEach, describe, expect, it, vi } from 'vitest'
import { RnnoiseTrackProcessor } from './rnnoise_track_processor'
afterEach(() => { vi.unstubAllGlobals(); vi.unstubAllEnvs(); vi.restoreAllMocks() })
describe('RNNoise graph ownership', () => {
  it('rejects unsupported before asset loads and never closes borrowed context or capture', async () => {
    vi.stubGlobal('window', { isSecureContext: false })
    const loadAssets = vi.fn(), onFailure = vi.fn(), stop = vi.fn(), close = vi.fn()
    const processor = new RnnoiseTrackProcessor({ loadAssets, onFailure })
    await expect(processor.init({ kind: 'audio', track: { stop } as unknown as MediaStreamTrack,
      audioContext: { sampleRate: 48000, close } as unknown as AudioContext } as never)).rejects.toThrow('unsupported')
    await processor.destroy()
    expect(loadAssets).not.toHaveBeenCalled(); expect(close).not.toHaveBeenCalled(); expect(stop).not.toHaveBeenCalled()
    expect(onFailure).toHaveBeenCalledWith('unsupported')
  })
})


describe('bounded initialization diagnostics', () => {
  function supportedEnvironment() {
    vi.stubGlobal('window', { isSecureContext: true })
    vi.stubGlobal('AudioContext', class { audioWorklet = {}; static prototypeMarker = true })
    Object.defineProperty(AudioContext.prototype, 'audioWorklet', { value: {} })
    vi.stubGlobal('AudioWorkletNode', class {})
  }
  it('reports original capture rate and elapsed initialization outside rendering', async () => {
    supportedEnvironment()
    vi.spyOn(performance, 'now').mockReturnValueOnce(10).mockReturnValueOnce(14.75)
    const processor = new RnnoiseTrackProcessor()
    await expect(processor.init({ kind: 'audio', track: { getSettings: () => ({ sampleRate: 32000 }) }, audioContext: { sampleRate: 44100 } } as never)).rejects.toThrow('48 kHz')
    expect(processor.runtimeState).toMatchObject({ captureSampleRate: 32000, contextSampleRate: 44100, initDurationMs: 4.75 })
  })
  it('preserves unknown capture rate and rejects nonfinite durations', async () => {
    supportedEnvironment()
    vi.spyOn(performance, 'now').mockReturnValueOnce(10).mockReturnValueOnce(Infinity)
    const processor = new RnnoiseTrackProcessor()
    await expect(processor.init({ kind: 'audio', track: { getSettings: () => ({ sampleRate: NaN }) }, audioContext: { sampleRate: 44100 } } as never)).rejects.toThrow('48 kHz')
    expect(processor.runtimeState.captureSampleRate).toBeUndefined()
    expect(processor.runtimeState.initDurationMs).toBeUndefined()
  })
  it('fails closed before graph creation when the enabled v0.2 asset is missing', async () => {
    supportedEnvironment()
    vi.stubEnv('VITE_RNNOISE_V02_ENABLED', 'true')
    vi.stubGlobal('window', { isSecureContext: true, location: { origin: 'https://voice.test' } })
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue(new Response('', { status: 404 })))
    const addModule = vi.fn(), failure = vi.fn()
    const processor = new RnnoiseTrackProcessor({ onFailure: failure })
    await expect(processor.init({ kind: 'audio', track: { getSettings: () => ({ sampleRate: 48000 }) },
      audioContext: { sampleRate: 48000, audioWorklet: { addModule } } } as never)).rejects.toThrow('manifest unavailable')
    expect(addModule).not.toHaveBeenCalled()
    expect(failure).toHaveBeenCalledWith('asset-load')
    expect(processor.processedTrack).toBeUndefined()
    expect(processor.runtimeState).toMatchObject({ effectiveMode: 'unknown', status: 'error', fallbackReason: 'asset-load' })
  })
})
