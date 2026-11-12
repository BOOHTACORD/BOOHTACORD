import { afterEach, describe, expect, it, vi } from 'vitest'
import { loadRnnoiseAssets } from './rnnoise_loader'
import { rnnoiseModels } from './rnnoise_model'
afterEach(() => { vi.unstubAllGlobals(); vi.unstubAllEnvs(); vi.restoreAllMocks() })
describe('RNNoise same origin manifest guard', () => {
  it('rejects external locations before any network request', async () => {
    vi.stubGlobal('window', { location: { origin: 'https://voice.test' } })
    const fetcher = vi.fn(); vi.stubGlobal('fetch', fetcher)
    await expect(loadRnnoiseAssets('https://third.test/noise.json')).rejects.toThrow('same origin')
    expect(fetcher).not.toHaveBeenCalled()
  })
  it('rejects HTML fallback assets and evicts failed loads', async () => {
    vi.stubGlobal('window', { location: { origin: 'https://voice.test' } })
    const fetcher = vi.fn().mockResolvedValue(new Response('<html>', { headers: { 'content-type': 'text/html' } }))
    vi.stubGlobal('fetch', fetcher)
    await expect(loadRnnoiseAssets('/bad-manifest')).rejects.toThrow('manifest unavailable')
    await expect(loadRnnoiseAssets('/bad-manifest')).rejects.toThrow('manifest unavailable')
    expect(fetcher).toHaveBeenCalledTimes(2)
  })
  it('loads the pinned v0.2 identity only when explicitly enabled', async () => {
    vi.stubEnv('VITE_RNNOISE_V02_ENABLED', 'true')
    vi.stubGlobal('window', { location: { origin: 'https://voice.test' } })
    vi.stubGlobal('crypto', { subtle: { digest: async () => new Uint8Array(32).buffer } })
    vi.spyOn(WebAssembly, 'compile').mockResolvedValue({} as WebAssembly.Module)
    vi.spyOn(WebAssembly.Module, 'imports').mockReturnValue([])
    const model = rnnoiseModels.v02
    const manifest = { ...model, frameSize: 480, sampleRate: 48000, pcmScale: 32768,
      threads: 1, simd: false, wasmFile: 'rnnoise.wasm', wasmSha256: '0'.repeat(64) }
    const fetcher = vi.fn().mockImplementation(async (url: URL) => url.pathname.endsWith('.json')
      ? new Response(JSON.stringify(manifest), { headers: { 'content-type': 'application/json' } })
      : new Response(new Uint8Array([1]), { headers: { 'content-type': 'application/wasm' } }))
    vi.stubGlobal('fetch', fetcher)
    expect((await loadRnnoiseAssets()).modelId).toBe('rnnoise-stock-v0.2')
    expect(fetcher.mock.calls[0][0].pathname).toBe(model.manifestPath)
  })
  it('does not reuse cached v0.1 assets after selecting v0.2 at the same path', async () => {
    vi.stubGlobal('window', { location: { origin: 'https://voice.test' } })
    vi.stubGlobal('crypto', { subtle: { digest: async () => new Uint8Array(32).buffer } })
    vi.spyOn(WebAssembly, 'compile').mockResolvedValue({} as WebAssembly.Module)
    vi.spyOn(WebAssembly.Module, 'imports').mockReturnValue([])
    let model = rnnoiseModels.v01
    const fetcher = vi.fn().mockImplementation(async (url: URL) => {
      const manifest = { ...model, frameSize: 480, sampleRate: 48000, pcmScale: 32768,
        threads: 1, simd: false, wasmFile: 'rnnoise.wasm', wasmSha256: '0'.repeat(64) }
      return url.pathname.endsWith('.json')
        ? new Response(JSON.stringify(manifest), { headers: { 'content-type': 'application/json' } })
        : new Response(new Uint8Array([1]), { headers: { 'content-type': 'application/wasm' } })
    })
    vi.stubGlobal('fetch', fetcher)
    vi.stubEnv('VITE_RNNOISE_V02_ENABLED', 'false')
    expect((await loadRnnoiseAssets('/same-path/manifest.json')).modelId).toBe('rnnoise-stock-v0.1')
    model = rnnoiseModels.v02
    vi.stubEnv('VITE_RNNOISE_V02_ENABLED', 'true')
    expect((await loadRnnoiseAssets('/same-path/manifest.json')).modelId).toBe('rnnoise-stock-v0.2')
    expect(fetcher).toHaveBeenCalledTimes(4)
  })
  it('rejects the wrong model manifest before fetching its WASM', async () => {
    vi.stubEnv('VITE_RNNOISE_V02_ENABLED', 'true')
    vi.stubGlobal('window', { location: { origin: 'https://voice.test' } })
    const fetcher = vi.fn().mockResolvedValue(new Response(JSON.stringify(rnnoiseModels.v01),
      { headers: { 'content-type': 'application/json' } }))
    vi.stubGlobal('fetch', fetcher)
    await expect(loadRnnoiseAssets('/wrong-model/manifest.json')).rejects.toThrow('manifest incompatible')
    expect(fetcher).toHaveBeenCalledTimes(1)
  })
})
