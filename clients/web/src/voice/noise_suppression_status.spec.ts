import { expect, it } from 'vitest'
import { noiseSuppressionStatus } from './noise_suppression_status'

it('reports the selected neural engine, fallback and safe failure', () => {
  expect(noiseSuppressionStatus('rnnoise', { requestedMode: 'rnnoise', effectiveMode: 'rnnoise', status: 'active' })).toBe('RNNoise активен.')
  expect(noiseSuppressionStatus('deepfilter', { requestedMode: 'deepfilter', effectiveMode: 'deepfilter', status: 'active' })).toBe('DeepFilterNet3 активен.')
  expect(noiseSuppressionStatus('deepfilter', { requestedMode: 'deepfilter', effectiveMode: 'browser', status: 'fallback', fallbackReason: 'asset-load' })).toContain('стандартная обработка')
  expect(noiseSuppressionStatus('deepfilter', { requestedMode: 'deepfilter', effectiveMode: 'unknown', status: 'error' })).toContain('Отправка звука выключена')
  expect(noiseSuppressionStatus('browser', { requestedMode: 'browser', effectiveMode: 'browser', status: 'active' })).toBe('')
})
