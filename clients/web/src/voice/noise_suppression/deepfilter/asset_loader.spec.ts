import { afterEach, beforeEach, expect, it, vi } from 'vitest'
import { loadDeepFilterAssets, researchIdentity } from './asset_loader'

beforeEach(() => {
  vi.stubGlobal('window', { location: { origin: 'https://voice.test' } })
  vi.stubGlobal('crypto', { subtle: { digest: vi.fn().mockImplementation(async (_alg, bytes: ArrayBuffer) => {
    const value = new Uint8Array(bytes)[0] === 1 ? researchIdentity.wasmSha256 : researchIdentity.modelSha256
    return Uint8Array.from(value.match(/../g)!, part => parseInt(part, 16)).buffer
  }) } })
  vi.spyOn(WebAssembly, 'compile').mockResolvedValue({} as WebAssembly.Module)
})
afterEach(() => { vi.unstubAllGlobals(); vi.restoreAllMocks() })

function response(bytes: number[], type: string) {
  return new Response(new Uint8Array(bytes), { headers: { 'content-type': type } })
}

it('loads only pinned same-origin assets and compiles the checked wasm', async () => {
  const fetcher = vi.fn().mockImplementation(async (url: URL) => url.pathname.endsWith('.wasm')
    ? response([1], 'application/wasm') : response([2], 'application/octet-stream'))
  vi.stubGlobal('fetch', fetcher)
  const assets = await loadDeepFilterAssets()
  expect(assets.model.byteLength).toBe(1)
  expect(WebAssembly.compile).toHaveBeenCalledTimes(1)
  expect(fetcher).toHaveBeenCalledTimes(2)
  for (const [url, options] of fetcher.mock.calls) {
    expect(url.origin).toBe('https://voice.test')
    expect(options).toMatchObject({ credentials: 'same-origin', redirect: 'error' })
  }
})

it('rejects corrupted model before compiling and rejects HTML fallbacks', async () => {
  vi.stubGlobal('fetch', vi.fn().mockImplementation(async (url: URL) => url.pathname.endsWith('.wasm')
    ? response([1], 'application/wasm') : response([1], 'application/octet-stream')))
  await expect(loadDeepFilterAssets()).rejects.toThrow('checksum')
  expect(WebAssembly.compile).not.toHaveBeenCalled()
  vi.stubGlobal('fetch', vi.fn().mockResolvedValue(response([1], 'text/html')))
  await expect(loadDeepFilterAssets()).rejects.toThrow('asset unavailable')
})

it('rejects oversized bodies and aborts a stalled fetch', async () => {
  vi.stubGlobal('fetch', vi.fn().mockImplementation(async (url: URL) => new Response(new Uint8Array([1]), {
    headers: { 'content-type': url.pathname.endsWith('.wasm') ? 'application/wasm' : 'application/octet-stream',
      'content-length': '999999999' },
  })))
  await expect(loadDeepFilterAssets()).rejects.toThrow('asset too large')
  const aborted = vi.fn()
  vi.stubGlobal('fetch', vi.fn().mockImplementation((_url, options) => new Promise((_resolve, reject) => {
    options.signal.addEventListener('abort', () => { aborted(); reject(new Error('aborted')) })
  })))
  await expect(loadDeepFilterAssets(10)).rejects.toThrow('asset timeout')
  expect(aborted).toHaveBeenCalledTimes(2)
})

it('enforces the size limit while streaming even without a content length', async () => {
  vi.stubGlobal('fetch', vi.fn().mockImplementation(async (url: URL) => {
    const isWasm = url.pathname.endsWith('.wasm')
    return new Response(isWasm ? new Uint8Array([1]) : new Uint8Array(9_000_001), {
      headers: { 'content-type': isWasm ? 'application/wasm' : 'application/octet-stream' },
    })
  }))
  await expect(loadDeepFilterAssets()).rejects.toThrow('asset too large')
  expect(WebAssembly.compile).not.toHaveBeenCalled()
})

it('bounds compilation time as well as network time', async () => {
  vi.stubGlobal('fetch', vi.fn().mockImplementation(async (url: URL) => url.pathname.endsWith('.wasm')
    ? response([1], 'application/wasm') : response([2], 'application/octet-stream')))
  vi.mocked(WebAssembly.compile).mockImplementation(() => new Promise(() => {}))
  await expect(loadDeepFilterAssets(10)).rejects.toThrow('asset timeout')
})
