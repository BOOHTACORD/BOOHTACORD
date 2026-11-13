import { expect, test } from '@playwright/test'

test('browser capture uses a safe RNNoise track and preserves mute', async ({ page }) => {
  await page.goto('/tests/audio/fixture.html')
  const result = await page.evaluate(async () => {
    const path = '/tests/audio/adapter_recapture_fixture.ts'
    return (await import(/* @vite-ignore */ path)).runAdapterRecapture()
  })
  if (result.events.filter((event: string) => event.startsWith('publish:')).length === 2) {
    expect(result.events).toEqual(['capture:true', 'publish:false', 'unpublish', 'capture:false', 'publish:false', 'unpublish'])
    expect(result.oldStopped).toBe(true)
  } else if (result.events[0] === 'capture:true') {
    expect(result.events).toEqual(['capture:true', 'publish:false', 'unpublish'])
  } else {
    expect(result.events).toEqual(['capture:false', 'capture:false', 'publish:false', 'unpublish'])
  }
  expect(result.active).toMatchObject({ requestedMode: 'rnnoise', effectiveMode: 'rnnoise', status: 'active' })
  expect(result.muted).toBe(true)
})
