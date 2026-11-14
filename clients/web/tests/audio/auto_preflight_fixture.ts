export async function measuredCandidates(engines: ('rnnoise' | 'deepfilter')[] = ['rnnoise', 'deepfilter']) {
  const root = '/src/voice/noise_suppression/'
  const rn = await import(/* @vite-ignore */ root + 'rnnoise_loader.ts')
  const df = await import(/* @vite-ignore */ root + 'deepfilter/asset_loader.ts')
  const client = await import(/* @vite-ignore */ root + 'auto_preflight/client.ts')
  const url = (await import(/* @vite-ignore */ root + 'auto_preflight/probe.worker.ts?worker&url')).default
  const results = []
  for (const engine of engines) {
    const assets = engine === 'rnnoise' ? await rn.loadRnnoiseAssets() : await df.loadDeepFilterAssets()
    const worker = new Worker(url, { type: 'module' })
    let timer: ReturnType<typeof setTimeout> | undefined
    try {
      const metrics = await new Promise<Record<string, unknown>>((resolve, reject) => {
        timer = setTimeout(() => reject(Error('preflight timeout')), 2000)
        worker.onmessage = event => resolve(event.data)
        worker.onerror = () => reject(Error('preflight worker error'))
        worker.postMessage({ engine, ...assets })
      })
      results.push({ engine, metrics, eligible: await client.preflightWebEngine(engine) })
    } finally { if (timer) clearTimeout(timer); worker.terminate() }
  }
  return results
}
