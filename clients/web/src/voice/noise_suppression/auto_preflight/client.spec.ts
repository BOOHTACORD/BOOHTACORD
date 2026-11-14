import { afterEach, expect, it, vi } from 'vitest'
import { preflightWebEngine } from './client'
import { loadRnnoiseAssets } from '../rnnoise_loader'
import { loadDeepFilterAssets } from '../deepfilter/asset_loader'
import { runWorker } from './worker_runner'
vi.mock('../rnnoise_loader', () => ({ loadRnnoiseAssets: vi.fn() }))
vi.mock('../deepfilter/asset_loader', () => ({ loadDeepFilterAssets: vi.fn() }))
vi.mock('./worker_runner', () => ({ runWorker: vi.fn() }))
afterEach(() => { vi.resetAllMocks(); vi.unstubAllGlobals() })
it('refuses unsupported workers and old or unidentified RNNoise models', async () => {
  vi.stubGlobal('Worker', undefined)
  expect(await preflightWebEngine('rnnoise')).toBe(false)
  vi.stubGlobal('Worker', class {})
  vi.mocked(loadRnnoiseAssets).mockResolvedValue({ modelId: 'rnnoise-stock-v0.1' } as never)
  expect(await preflightWebEngine('rnnoise')).toBe(false)
  expect(runWorker).not.toHaveBeenCalled()
})
it('probes only verified loaded assets and propagates rejection', async () => {
  vi.stubGlobal('Worker', class {})
  const assets = { module: {}, modelId: 'rnnoise-stock-v0.2' }
  vi.mocked(loadRnnoiseAssets).mockResolvedValue(assets as never)
  vi.mocked(runWorker).mockResolvedValueOnce(true).mockResolvedValueOnce(false)
  expect(await preflightWebEngine('rnnoise')).toBe(true)
  expect(runWorker).toHaveBeenLastCalledWith({ engine: 'rnnoise', ...assets }, expect.any(Function))
  vi.mocked(loadDeepFilterAssets).mockResolvedValue({ module: {}, model: new Uint8Array(4) } as never)
  expect(await preflightWebEngine('deepfilter')).toBe(false)
})
it('fails closed on asset integrity or transport errors', async () => {
  vi.stubGlobal('Worker', class {})
  vi.mocked(loadDeepFilterAssets).mockRejectedValue(Error('checksum'))
  expect(await preflightWebEngine('deepfilter')).toBe(false)
})
