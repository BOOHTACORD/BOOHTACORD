import { loadRnnoiseAssets } from '../rnnoise_loader'
import { loadDeepFilterAssets } from '../deepfilter/asset_loader'
import { runWorker } from './worker_runner'
import workerUrl from './probe.worker.ts?worker&url'

/** Per preparation: no persistent hardware verdict, PCM or user/device IDs. */
export async function preflightWebEngine(engine: 'rnnoise' | 'deepfilter'): Promise<boolean> {
  if (typeof Worker === 'undefined') return false
  try {
    const assets = engine === 'rnnoise' ? await loadRnnoiseAssets() : await loadDeepFilterAssets()
    if (engine === 'rnnoise' && (!('modelId' in assets) || assets.modelId !== 'rnnoise-stock-v0.2')) return false
    return await runWorker({ engine, ...assets }, () => new Worker(workerUrl, { type: 'module' }))
  } catch { return false }
}
