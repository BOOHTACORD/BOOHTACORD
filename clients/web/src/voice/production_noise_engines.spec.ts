import { afterEach, expect, it, vi } from 'vitest'
import { createSSRApp, h } from 'vue'
import { renderToString } from '@vue/server-renderer'
import NoiseSuppressionSelect from './NoiseSuppressionSelect.vue'
import { selectRnnoiseModel } from './noise_suppression/rnnoise_model'
import { deepfilterReleaseEnabled } from './noise_suppression/capabilities'
import { noiseSuppressionStatus } from './noise_suppression_status'

afterEach(() => vi.unstubAllEnvs())

it('ordinary builds select the complete official RNNoise 0.2 distribution', () => {
  vi.stubEnv('VITE_RNNOISE_V02_ENABLED', undefined)
  expect(selectRnnoiseModel(undefined).modelId).toBe('rnnoise-release-v0.2')
  expect(selectRnnoiseModel(undefined).modelSha256).toBe('dece58eabca6a722a0bd9dbc8dfadba27abac1271760fad65e1071f54717dc78')
})

it('ordinary settings expose both engine versions and Auto without research flags', async () => {
  vi.stubEnv('VITE_DEEPFILTER_ENABLED', undefined)
  vi.stubEnv('VITE_RNNOISE_V02_ENABLED', undefined)
  expect(deepfilterReleaseEnabled()).toBe(true)
  const html = await renderToString(createSSRApp({ render: () => h(NoiseSuppressionSelect, { mode: 'rnnoise' }) }))
  expect(html).toContain('RNNoise 0.2')
  expect(html).toContain('DeepFilterNet3')
  expect(html).toContain('Автоматически')
  expect(html).not.toContain('экспериментальное')
})

it('active runtime status names the actual reported RNNoise version', () => {
  expect(noiseSuppressionStatus('rnnoise', { requestedMode: 'rnnoise', effectiveMode: 'rnnoise',
    status: 'active', modelId: 'rnnoise-release-v0.2' })).toContain('RNNoise 0.2')
})
