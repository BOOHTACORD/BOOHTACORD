import { afterEach, expect, it, vi } from 'vitest'
import { loadRnnoiseAssets } from './rnnoise_loader'
import { rnnoiseModels } from './rnnoise_model'

afterEach(() => { vi.unstubAllEnvs(); vi.unstubAllGlobals(); vi.restoreAllMocks() })

it('refuses v0.2 before fetching when its trusted build digest is absent', async () => {
  vi.stubEnv('VITE_RNNOISE_V02_ENABLED', 'true')
  vi.stubEnv('VITE_RNNOISE_V02_WASM_SHA256', '')
  vi.stubGlobal('window', { location: { origin: 'https://voice.test' } })
  const fetcher = vi.fn(); vi.stubGlobal('fetch', fetcher)
  await expect(loadRnnoiseAssets('/unbound-v02')).rejects.toThrow('RNNoise v0.2 WASM identity missing')
  expect(fetcher).not.toHaveBeenCalled()
})

it('rejects a manifest that replaces its own digest before downloading WASM', async () => {
  vi.stubEnv('VITE_RNNOISE_V02_ENABLED', 'true')
  vi.stubEnv('VITE_RNNOISE_V02_WASM_SHA256', 'a'.repeat(64))
  vi.stubGlobal('window', { location: { origin: 'https://voice.test' } })
  const manifest = { ...rnnoiseModels.v02, frameSize: 480, sampleRate: 48000, pcmScale: 32768,
    threads: 1, simd: false, wasmFile: 'rnnoise.wasm', wasmSha256: 'b'.repeat(64) }
  const fetcher = vi.fn().mockResolvedValue(new Response(JSON.stringify(manifest),
    { headers: { 'content-type': 'application/json' } }))
  vi.stubGlobal('fetch', fetcher)
  await expect(loadRnnoiseAssets('/forged-v02/manifest.json')).rejects.toThrow('RNNoise manifest incompatible')
  expect(fetcher).toHaveBeenCalledTimes(1)
})

it('does not reuse a cached module after the trusted digest changes', async () => {
  vi.stubEnv('VITE_RNNOISE_V02_ENABLED', 'true')
  vi.stubEnv('VITE_RNNOISE_V02_WASM_SHA256', '0'.repeat(64))
  vi.stubGlobal('window', { location: { origin: 'https://voice.test' } })
  vi.stubGlobal('crypto', { subtle: { digest: async () => new Uint8Array(32).buffer } })
  vi.spyOn(WebAssembly, 'compile').mockResolvedValue({} as WebAssembly.Module)
  vi.spyOn(WebAssembly.Module, 'imports').mockReturnValue([])
  const manifest = { ...rnnoiseModels.v02, frameSize: 480, sampleRate: 48000, pcmScale: 32768,
    threads: 1, simd: false, wasmFile: 'rnnoise.wasm', wasmSha256: '0'.repeat(64) }
  const fetcher = vi.fn().mockImplementation(async (url: URL) => url.pathname.endsWith('.json')
    ? new Response(JSON.stringify(manifest), { headers: { 'content-type': 'application/json' } })
    : new Response(new Uint8Array([1]), { headers: { 'content-type': 'application/wasm' } }))
  vi.stubGlobal('fetch', fetcher)
  await loadRnnoiseAssets('/digest-cache/manifest.json')
  vi.stubEnv('VITE_RNNOISE_V02_WASM_SHA256', '1'.repeat(64))
  await expect(loadRnnoiseAssets('/digest-cache/manifest.json')).rejects.toThrow('RNNoise manifest incompatible')
  expect(fetcher).toHaveBeenCalledTimes(3)
})

it('rejects WASM bytes that do not match the trusted digest', async () => {
  vi.stubEnv('VITE_RNNOISE_V02_ENABLED', 'true')
  vi.stubEnv('VITE_RNNOISE_V02_WASM_SHA256', '0'.repeat(64))
  vi.stubGlobal('window', { location: { origin: 'https://voice.test' } })
  vi.stubGlobal('crypto', { subtle: { digest: async () => new Uint8Array(32).fill(1).buffer } })
  const manifest = { ...rnnoiseModels.v02, frameSize: 480, sampleRate: 48000, pcmScale: 32768,
    threads: 1, simd: false, wasmFile: 'rnnoise.wasm', wasmSha256: '0'.repeat(64) }
  const fetcher = vi.fn().mockImplementation(async (url: URL) => url.pathname.endsWith('.json')
    ? new Response(JSON.stringify(manifest), { headers: { 'content-type': 'application/json' } })
    : new Response(new Uint8Array([1]), { headers: { 'content-type': 'application/wasm' } }))
  vi.stubGlobal('fetch', fetcher)
  const compile = vi.spyOn(WebAssembly, 'compile')
  await expect(loadRnnoiseAssets('/wrong-bytes/manifest.json')).rejects.toThrow('RNNoise WASM checksum mismatch')
  expect(compile).not.toHaveBeenCalled()
})
