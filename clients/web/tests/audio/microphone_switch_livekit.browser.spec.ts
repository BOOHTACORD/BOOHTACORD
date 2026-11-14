import { expect, test } from '@playwright/test'

test('processing switches preserve one live publication and receiver audio', async ({ browser, browserName }) => {
  const senderContext = await browser.newContext(browserName === 'firefox' ? {} : { permissions: ['microphone'] })
  const receiverContext = await browser.newContext()
  const sender = await senderContext.newPage(), receiver = await receiverContext.newPage()
  const hear = async () => expect.poll(async () => {
    const result = await receiver.evaluate(() => (window as any).livekitAudioGate.read())
    return result.readings.some((reading: any) => reading.rms > 0.0001 && reading.nonfinite === 0)
  }, { timeout: 15000 }).toBe(true)
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
    expect(await sender.evaluate(() => (window as any).microphoneJoinGate.join('browser', false)))
      .toMatchObject({ microphone: 'PUBLISHED', publications: 1 })
    await hear()
    for (const mode of ['rnnoise', 'off', 'browser'] as const) {
      const before = await receiver.evaluate(() => (window as any).livekitAudioGate.read())
      const state = await sender.evaluate(mode => (window as any).microphoneJoinGate.switchMode(mode), mode)
      expect(state).toMatchObject({ publications: 1, processing: { requestedMode: mode } })
      if (browserName === 'firefox' && mode === 'browser' && state.processing.effectiveMode === 'off')
        expect(state.processing.status).toBe('unsupported')
      else expect(state.processing.effectiveMode).toBe(mode)
      if (mode === 'rnnoise') expect(state.processing.modelId).toBe(
        process.env.VITE_RNNOISE_V02_ENABLED === 'true' ? 'rnnoise-stock-v0.2' : 'rnnoise-stock-v0.1')
      if (state.replaced) await expect.poll(async () => {
        const next = await receiver.evaluate(() => (window as any).livekitAudioGate.read())
        return next.subscriptions
      }, { timeout: 15000 }).toBeGreaterThan(before.subscriptions)
      await hear()
    }
    await sender.evaluate(() => (window as any).microphoneJoinGate.mute())
    await receiver.waitForTimeout(500)
    await receiver.evaluate(() => (window as any).livekitAudioGate.read())
    await receiver.waitForTimeout(500)
    const muted = await receiver.evaluate(() => (window as any).livekitAudioGate.read())
    expect(muted.readings.length).toBeGreaterThan(0)
    expect(muted.readings.every((reading: any) => reading.peak < 0.0001)).toBe(true)
  } finally {
    await sender.evaluate(() => (window as any).microphoneJoinGate?.stop()).catch(() => {})
    await receiver.evaluate(() => (window as any).livekitAudioGate?.stop()).catch(() => {})
    await senderContext.close(); await receiverContext.close()
  }
})
