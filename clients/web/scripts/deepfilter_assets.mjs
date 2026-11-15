import { prepareAssets } from '../../../tools/audio/research_dfn_web/stage.mjs'
import { readProductionAssets, assetRoot } from '../../../tools/audio/release_web_assets/bundle.mjs'
import { verifiedAssetsPlugin } from '../../../tools/audio/release_web_assets/vite.mjs'
import { join } from 'node:path'

const prefix = 'audio/deepfilternet/research-d375b2d/'
export function deepfilterAssetsPlugin({ enabled, bundle }) {
  return verifiedAssetsPlugin({ name: 'deepfilter-production-assets', prefix, enabled,
    async prepare() {
      const verified = await readProductionAssets()
      const files = await prepareAssets(bundle ?? join(assetRoot, 'deepfilter'))
      for (const [file, bytes] of verified) {
        if (!file.startsWith('deepfilter/')) continue
        const name = file.slice('deepfilter/'.length)
        if (!['dfn.js', 'dfn_bg.wasm', 'model.bin'].includes(name)) files.set(name, bytes)
      }
      return files
    },
  })
}
