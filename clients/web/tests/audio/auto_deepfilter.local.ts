import { expect, test } from '@playwright/test'

test('research Auto sends DeepFilter audio through a local SFU and preserves mute', async ({ browser }) => {
  expect(process.env.VITE_AUTO_DEEPFILTER_RESEARCH).toBe('true')
  expect(process.env.VITE_DEEPFILTER_ENABLED).toBe('true')
  const senderContext = await browser.newContext({ permissions: ['microphone'] })
  const receiverContext = await browser.newContext()
  const sender = await senderContext.newPage(), receiver = await receiverContext.newPage()
  try {
    await sender.addInitScript(() => {
      const Native = window.AudioContext
      window.AudioContext = class extends Native {
        constructor(options?: AudioContextOptions) { super({ ...options, sampleRate: 48000 }) }
      }
    })
    for (const page of [sender, receiver]) {
      await page.goto('/tests/audio/fixture.html')
      await page.waitForFunction(() => 'microphoneJoinGate' in window && 'livekitAudioGate' in window)
    }
    await receiver.evaluate(() => (window as any).livekitAudioGate.receiver())
    const joined = await sender.evaluate(() => (window as any).microphoneJoinGate.join('auto', false))
    expect(joined, JSON.stringify(joined.processingState)).toMatchObject({ microphone: 'PUBLISHED', publications: 1,
      enabledAtPublish: [false], processingState: { requestedMode: 'auto', effectiveMode: 'deepfilter', status: 'active' } })
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
