import { expect, test } from '@playwright/test'
import { eligible } from '../../src/voice/noise_suppression/auto_preflight/benchmark'

test('pinned DeepFilter WASM runs measured synthetic preflight outside capture', async ({ page }) => {
  await page.goto('/tests/audio/fixture.html')
  const [result] = await page.evaluate(async () => {
    const path = '/tests/audio/auto_preflight_fixture.ts'
    return (await import(/* @vite-ignore */ path)).measuredCandidates(['deepfilter'])
  })
  // Load/inference must actually finish; overloaded CI hardware may reject Auto.
  expect(result.engine).toBe('deepfilter')
  expect(result.metrics.frames, JSON.stringify(result)).toBe(32)
  expect([result.metrics.p95Ms, result.metrics.maxMs, result.metrics.elapsedMs].every(Number.isFinite)).toBe(true)
  expect(eligible(result.metrics)).toBe(result.metrics.ready)
  expect(typeof result.eligible).toBe('boolean')
  console.log(JSON.stringify({ gate: 'deepfilter-worker-preflight', ...result, acousticQuality: 'NOT_RUN' }))
})
