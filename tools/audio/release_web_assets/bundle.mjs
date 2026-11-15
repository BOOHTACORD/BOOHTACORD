import { createHash } from 'node:crypto'
import { readFile } from 'node:fs/promises'
import { join } from 'node:path'
import { fileURLToPath } from 'node:url'

export const assetRoot = fileURLToPath(new URL('../runtime_assets/', import.meta.url))
const identity = JSON.parse(await readFile(new URL('identity.json', import.meta.url), 'utf8'))

export async function readProductionAssets(root = assetRoot) {
  const assets = new Map()
  if (identity.scope !== 'production' || identity.schema_version !== 1) throw new Error('Invalid engine delivery identity')
  for (const [file, expected] of Object.entries(identity.files)) {
    const bytes = await readFile(join(root, file))
    if (createHash('sha256').update(bytes).digest('hex') !== expected)
      throw new Error('Production engine asset checksum mismatch: ' + file)
    assets.set(file, bytes)
  }
  const rnnoise = JSON.parse(assets.get('rnnoise/rnnoise-manifest.json'))
  const deepfilter = JSON.parse(assets.get('deepfilter/engine.json'))
  if (rnnoise.buildKind !== 'production' || rnnoise.modelId !== 'rnnoise-release-v0.2' ||
      deepfilter.scope !== 'production' || deepfilter.version !== 'DeepFilterNet3' || deepfilter.unresolved.length)
    throw new Error('Unqualified production noise engine')
  return assets
}
