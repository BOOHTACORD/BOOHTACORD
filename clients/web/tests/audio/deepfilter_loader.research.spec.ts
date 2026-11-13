import { expect, test } from '@playwright/test'

test('experimental loader verifies and compiles the actual pinned assets', async ({ page }) => {
  await page.goto('/tests/audio/fixture.html')
  const result = await page.evaluate(async () => {
    const path = '/src/voice/noise_suppression/deepfilter/asset_loader.ts'
    const { loadDeepFilterAssets } = await import(/* @vite-ignore */ path)
    const { module, model } = await loadDeepFilterAssets(30000)
    return { compiled: module instanceof WebAssembly.Module, modelBytes: model.length }
  })
  expect(result).toEqual({ compiled: true, modelBytes: 7983136 })
})
