import { readProductionAssets } from '../../../tools/audio/release_web_assets/bundle.mjs'
import { verifiedAssetsPlugin } from '../../../tools/audio/release_web_assets/vite.mjs'

export function rnnoiseProductionAssets({ enabled }) {
  return verifiedAssetsPlugin({ name: 'rnnoise-production-assets', enabled,
    prefix: 'audio/rnnoise/v0.2-904a876/',
    async prepare() {
      const files = await readProductionAssets()
      return new Map([...files].filter(([file]) => file.startsWith('rnnoise/'))
        .map(([file, bytes]) => [file.slice('rnnoise/'.length), bytes]))
    },
  })
}
