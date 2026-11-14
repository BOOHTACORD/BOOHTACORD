import { expect, test } from '@playwright/test'

const seconds = Number(process.env.BOOHTA_ENDURANCE_SECONDS ?? 0)
test.skip(!Number.isInteger(seconds) || seconds < 10 || seconds > 1800, 'Opt-in bounded endurance test')
test.setTimeout(1_890_000)
test('synthetic call survives repeated experimental engine switches', async ({ browser }) => {
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
    await sender.evaluate(() => (window as any).microphoneJoinGate.join('browser', false))
    const start = Date.now()
    let rounds = 0
    while (Date.now() - start < seconds * 1000) {
      const mode = rounds % 2 ? 'deepfilter' : 'rnnoise'
      const state = await sender.evaluate(mode => (window as any).microphoneJoinGate.switchMode(mode), mode)
      expect(state).toMatchObject({ publications: 1, processing: { effectiveMode: mode } })
      if (mode === 'rnnoise') expect(state.processing.modelId).toBe('rnnoise-stock-v0.2')
      await receiver.waitForTimeout(Math.min(30_000, Math.max(1000, seconds * 1000 - (Date.now() - start))))
      const remote = await receiver.evaluate(() => (window as any).livekitAudioGate.read())
      expect(remote.state).toBe('connected')
      expect(remote.readings.some((reading: any) => reading.rms > 0.0001 && reading.nonfinite === 0)).toBe(true)
      rounds++
    }
    console.log(JSON.stringify({ elapsedSeconds: Math.round((Date.now() - start) / 1000), switches: rounds }))
  } finally {
    await sender.evaluate(() => (window as any).microphoneJoinGate?.stop()).catch(() => {})
    await receiver.evaluate(() => (window as any).livekitAudioGate?.stop()).catch(() => {})
    await senderContext.close(); await receiverContext.close()
  }
})
