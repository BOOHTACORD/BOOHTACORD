import { expect, test } from '@playwright/test'
test('two isolated browsers send processed microphone PCM through actual LiveKit', async ({ browser }) => {
  const senderContext = await browser.newContext(), receiverContext = await browser.newContext()
  const sender = await senderContext.newPage(), receiver = await receiverContext.newPage()
  try {
    for (const page of [sender, receiver]) { await page.goto('/tests/audio/fixture.html'); await page.waitForFunction(() => 'livekitAudioGate' in window) }
    await receiver.evaluate(() => (window as any).livekitAudioGate.receiver())
    expect(await sender.evaluate(() => (window as any).livekitAudioGate.sender())).toEqual({
      engine: 'rnnoise', sampleRate: 48000,
      modelId: process.env.VITE_RNNOISE_V02_ENABLED === 'true' ? 'rnnoise-stock-v0.2' : 'rnnoise-stock-v0.1',
    })
    await expect.poll(async () => {
      const sample = await receiver.evaluate(() => (window as any).livekitAudioGate.read())
      return sample.readings.some((reading: any) => reading.rms > 0.001 && reading.nonfinite === 0)
    }, { timeout: 15000 }).toBe(true)
    await sender.evaluate(() => (window as any).livekitAudioGate.mute())
    await receiver.waitForTimeout(400); await receiver.evaluate(() => (window as any).livekitAudioGate.resetMeter())
    await receiver.waitForTimeout(400)
    const muted = await receiver.evaluate(() => (window as any).livekitAudioGate.read())
    expect(muted.readings.length).toBeGreaterThan(0)
    expect(muted.readings.every((reading: any) => reading.peak < 0.0001)).toBe(true)
    console.log(JSON.stringify({ gate: 'two-browser-LiveKit-processed-microphone', status: 'PASS', browser: browser.version(), server: '1.13.7', physicalMicrophone: 'NOT_RUN', acousticQuality: 'NOT_RUN' }))
  } finally {
    for (const page of [sender, receiver]) if (!page.isClosed()) await page.evaluate(() => (window as any).livekitAudioGate?.stop()).catch(() => {})
    await senderContext.close(); await receiverContext.close()
  }
})
