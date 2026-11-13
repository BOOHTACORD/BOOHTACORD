import { prepareAssets } from '../../../tools/audio/research_dfn_web/stage.mjs'

const prefix = 'audio/deepfilternet/research-d375b2d/'
export function deepfilterAssetsPlugin({ enabled, bundle }) {
  let assets
  return {
    name: 'deepfilter-research-assets',
    async buildStart() {
      if (!enabled) return
      if (!bundle) throw new Error('DeepFilter research bundle is required for an enabled build')
      assets = await prepareAssets(bundle)
    },
    generateBundle() {
      if (!enabled) return
      if (!assets) throw new Error('DeepFilter research assets were not verified')
      for (const [name, source] of assets) this.emitFile({ type: 'asset', fileName: prefix + name, source })
    },
  }
}
