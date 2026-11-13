import { expect, test } from '@playwright/test'

test('experimental DeepFilter track reaches another browser through local LiveKit', async ({ browser }) => {
  const senderContext = await browser.newContext(), receiverContext = await browser.newContext()
  const sender = await senderContext.newPage(), receiver = await receiverContext.newPage()
  try {
    for (const page of [sender, receiver]) { await page.goto('/tests/audio/fixture.html'); await page.waitForFunction(() => 'livekitAudioGate' in window) }
    await receiver.evaluate(() => (window as any).livekitAudioGate.receiver())
    expect(await sender.evaluate(() => (window as any).livekitAudioGate.sender('deepfilter-research')))
      .toEqual({ engine: 'deepfilter-research', sampleRate: 48000 })
    await expect.poll(async () => {
      const sample = await receiver.evaluate(() => (window as any).livekitAudioGate.read())
      return sample.readings.some((reading: any) => reading.rms > .001 && reading.nonfinite === 0)
    }, { timeout: 15000 }).toBe(true)
    expect(await sender.evaluate(() => (window as any).livekitAudioGate.mute())).toEqual({ localMuted: true, outputEnabled: false })
    await receiver.waitForTimeout(400); await receiver.evaluate(() => (window as any).livekitAudioGate.resetMeter())
    await receiver.waitForTimeout(400)
    const muted = await receiver.evaluate(() => (window as any).livekitAudioGate.read())
    expect(muted.state).toBe('connected')
    expect(muted.readings.length).toBeGreaterThan(0)
    expect(muted.readings.every((reading: any) => reading.peak < .0001 && reading.nonfinite === 0)).toBe(true)
  } finally {
    for (const page of [sender, receiver]) if (!page.isClosed()) await page.evaluate(() => (window as any).livekitAudioGate?.stop()).catch(() => {})
    await senderContext.close(); await receiverContext.close()
  }
})
