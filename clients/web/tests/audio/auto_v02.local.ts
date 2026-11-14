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

test('research Auto publishes processed audio through the local SFU and respects mute', async ({ browser }) => {
  expect(process.env.VITE_RNNOISE_V02_ENABLED).toBe('true')
  const senderContext = await browser.newContext({ permissions: ['microphone'] })
  const receiverContext = await browser.newContext()
  const sender = await senderContext.newPage(), receiver = await receiverContext.newPage()
  try {
    await sender.addInitScript(() => {
      const NativeAudioContext = window.AudioContext
      window.AudioContext = class extends NativeAudioContext {
        constructor(options?: AudioContextOptions) { super({ ...options, sampleRate: 48000 }) }
      }
    })
    for (const page of [sender, receiver]) {
      await page.goto('/tests/audio/fixture.html')
      await page.waitForFunction(() => 'microphoneJoinGate' in window && 'livekitAudioGate' in window)
    }
    await receiver.evaluate(() => (window as any).livekitAudioGate.receiver())
    const joined = await sender.evaluate(() => (window as any).microphoneJoinGate.join('auto', false))
    expect(joined, JSON.stringify(joined.processingState)).toMatchObject({ microphone: 'PUBLISHED', publications: 1, enabledAtPublish: [false],
      processingState: { requestedMode: 'auto', effectiveMode: 'rnnoise', status: 'active', modelId: 'rnnoise-stock-v0.2' } })
    await expect.poll(async () => {
      const sample = await receiver.evaluate(() => (window as any).livekitAudioGate.read())
      return sample.readings.some((value: any) => value.rms > 0.001 && value.nonfinite === 0)
    }, { timeout: 15000 }).toBe(true)
    await sender.evaluate(() => (window as any).microphoneJoinGate.mute())
    await receiver.waitForTimeout(400)
    await receiver.evaluate(() => (window as any).livekitAudioGate.read())
    await receiver.waitForTimeout(400)
    const muted = await receiver.evaluate(() => (window as any).livekitAudioGate.read())
    expect(muted.readings.length).toBeGreaterThan(0)
    expect(muted.readings.every((value: any) => value.peak < 0.0001 && value.nonfinite === 0)).toBe(true)
  } finally {
    await sender.evaluate(() => (window as any).microphoneJoinGate?.stop()).catch(() => {})
    await receiver.evaluate(() => (window as any).livekitAudioGate?.stop()).catch(() => {})
    await senderContext.close(); await receiverContext.close()
  }
})

test('research Auto falls back safely when the audio context is 44.1 kHz', async ({ browser }) => {
  expect(process.env.VITE_RNNOISE_V02_ENABLED).toBe('true')
  const context = await browser.newContext({ permissions: ['microphone'] })
  const page = await context.newPage()
  try {
    await page.addInitScript(() => {
      const NativeAudioContext = window.AudioContext
      window.AudioContext = class extends NativeAudioContext {
        constructor(options?: AudioContextOptions) { super({ ...options, sampleRate: 44100 }) }
      }
    })
    await page.goto('/tests/audio/fixture.html')
    await page.waitForFunction(() => 'microphoneJoinGate' in window)
    const joined = await page.evaluate(() => (window as any).microphoneJoinGate.join('auto', false))
    expect(joined).toMatchObject({ microphone: 'PUBLISHED', publications: 1, enabledAtPublish: [false],
      processingState: { requestedMode: 'auto', effectiveMode: 'browser', status: 'fallback', fallbackReason: 'sample-rate' } })
  } finally {
    await page.evaluate(() => (window as any).microphoneJoinGate?.stop()).catch(() => {})
    await context.close()
  }
})
