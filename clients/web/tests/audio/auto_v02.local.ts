import { expect, test } from '@playwright/test'

test('research Auto initializes the pinned RNNoise v0.2 processor', async ({ page }) => {
  expect(process.env.VITE_RNNOISE_V02_ENABLED).toBe('true')
  await page.goto('/tests/audio/fixture.html')
  const result = await page.evaluate(async () => {
    const path = '/tests/audio/adapter_recapture_fixture.ts'
    return (await import(/* @vite-ignore */ path)).runAutoCapture()
  })
  expect(result.rejected).toBe(false)
  expect(result.active).toMatchObject({ requestedMode: 'auto', effectiveMode: 'rnnoise', status: 'active', modelId: 'rnnoise-stock-v0.2' })
  expect(result.publishedMuted).toBe(true)
  expect(result.muted).toBe(true)
})
