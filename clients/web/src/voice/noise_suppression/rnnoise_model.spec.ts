import { describe, expect, it } from 'vitest'
import { selectRnnoiseModel, rnnoiseModels } from './rnnoise_model'

describe('RNNoise model selection', () => {
  it('keeps the existing model unless v0.2 is explicitly enabled', () => {
    for (const value of [undefined, '', 'false', 'TRUE']) expect(selectRnnoiseModel(value)).toBe(rnnoiseModels.v01)
    expect(selectRnnoiseModel('true')).toBe(rnnoiseModels.v02)
  })

  it('pins independent source and model identities for both assets', () => {
    expect(rnnoiseModels.v01.modelId).toBe('rnnoise-stock-v0.1')
    expect(rnnoiseModels.v02.modelId).toBe('rnnoise-stock-v0.2')
    expect(rnnoiseModels.v01.sourceCommit).not.toBe(rnnoiseModels.v02.sourceCommit)
    expect(rnnoiseModels.v02.manifestPath).toBe('/audio/rnnoise/v0.2-904a876/rnnoise-manifest.json')
    for (const model of Object.values(rnnoiseModels)) {
      expect(model.sourceCommit).toMatch(/^[0-9a-f]{40}$/)
      expect(model.sourceArchiveSha256).toMatch(/^[0-9a-f]{64}$/)
      expect(model.modelSha256).toMatch(/^[0-9a-f]{64}$/)
    }
  })
})
