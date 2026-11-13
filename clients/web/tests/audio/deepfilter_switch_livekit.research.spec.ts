import { expect, test } from '@playwright/test'

test('opt-in DeepFilter switches in a live call without losing receiver audio', async ({ browser }) => {
  const senderContext = await browser.newContext({ permissions: ['microphone'] })
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
    await sender.evaluate(() => (window as any).microphoneJoinGate.join('browser', false))
    await hear()
    for (const mode of ['deepfilter', 'browser'] as const) {
      const before = await receiver.evaluate(() => (window as any).livekitAudioGate.read())
      const result = await sender.evaluate(mode => (window as any).microphoneJoinGate.switchMode(mode), mode)
      expect(result).toMatchObject({ publications: 1, processing: { requestedMode: mode, effectiveMode: mode } })
      if (result.replaced) await expect.poll(async () => {
        return (await receiver.evaluate(() => (window as any).livekitAudioGate.read())).subscriptions
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
