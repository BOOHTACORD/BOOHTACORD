import { expect, test } from '@playwright/test'

test('real research WASM candidates meet the local eligibility budget', async ({ page }) => {
  expect(process.env.VITE_RNNOISE_V02_ENABLED).toBe('true')
  await page.goto('/tests/audio/fixture.html')
  const results = await page.evaluate(async () => {
    const path = '/tests/audio/auto_preflight_fixture.ts'
    return (await import(/* @vite-ignore */ path)).measuredCandidates()
  })
  expect(results.map((value: any) => value.engine)).toEqual(['rnnoise', 'deepfilter'])
  for (const value of results) {
    expect(value.metrics.ready, JSON.stringify(value)).toBe(true)
    expect(value.metrics.frames).toBe(32)
    expect(value.eligible, JSON.stringify(value)).toBe(true)
  }
  console.log(JSON.stringify({ gate: 'measured-web-auto-preflight', results, speechQuality: 'NOT_RUN' }))
})

test('injected DeepFilter overload recovers real measured RNNoise through local LiveKit', async ({ browser }) => {
  expect(process.env.VITE_AUTO_DEEPFILTER_RESEARCH).toBe('true')
  const senderContext = await browser.newContext({ permissions: ['microphone'] }), receiverContext = await browser.newContext()
  const sender = await senderContext.newPage(), receiver = await receiverContext.newPage()
  try {
    await sender.addInitScript(() => {
      const Base = window.AudioContext
      window.AudioContext = class extends Base {
        constructor(options?: AudioContextOptions) {
          super({ ...options, sampleRate: 48000 })
          const addModule = this.audioWorklet.addModule.bind(this.audioWorklet)
          this.audioWorklet.addModule = (url, options) => {
            if (new URL(String(url), location.href).pathname === '/audio/deepfilternet/research-d375b2d/deepfilter/worklet.js') {
              ;(window as any).__autoFaultInjections = ((window as any).__autoFaultInjections ?? 0) + 1
              return addModule('/tests/audio/deepfilter_overload.worklet.js', options)
            }
            return addModule(url, options)
          }
        }
      }
    })
    for (const page of [sender, receiver]) {
      await page.goto('/tests/audio/fixture.html')
      await page.waitForFunction(() => 'microphoneJoinGate' in window && 'livekitAudioGate' in window)
    }
    await receiver.evaluate(() => (window as any).livekitAudioGate.receiver())
    await sender.evaluate(() => (window as any).microphoneJoinGate.join('auto', false))
    expect(await sender.evaluate(() => (window as any).__autoFaultInjections), 'fault module must actually replace the research worklet').toBe(1)
    try {
      await expect.poll(async () => (await sender.evaluate(() => (window as any).microphoneJoinGate.readProcessing())).state.effectiveMode,
        { timeout: 15000 }).toBe('rnnoise')
    } catch {
      throw Error(JSON.stringify(await sender.evaluate(() => (window as any).microphoneJoinGate.readProcessing())))
    }
    await sender.waitForTimeout(1300) // Include a subsequent RNNoise health update.
    const recovered = await sender.evaluate(() => (window as any).microphoneJoinGate.readProcessing())
    expect(recovered.history).toContain('auto:deepfilter:active')
    expect(recovered.state).toMatchObject({ requestedMode: 'auto', effectiveMode: 'rnnoise', status: 'active',
      modelId: 'rnnoise-stock-v0.2', fallbackReason: 'overload' })
    await expect.poll(async () => (await receiver.evaluate(() => (window as any).livekitAudioGate.read())).readings
      .some((r: any) => r.rms > .001 && r.nonfinite === 0), { timeout: 15000 }).toBe(true)
  } finally {
    await sender.evaluate(() => (window as any).microphoneJoinGate?.stop()).catch(() => {})
    await receiver.evaluate(() => (window as any).livekitAudioGate?.stop()).catch(() => {})
    await senderContext.close(); await receiverContext.close()
  }
})

test('measured Auto publishes the opted-in candidate through local LiveKit and mutes', async ({ browser }) => {
  const engine = process.env.VITE_AUTO_DEEPFILTER_RESEARCH === 'true' ? 'deepfilter' : 'rnnoise'
  const senderContext = await browser.newContext({ permissions: ['microphone'] }), receiverContext = await browser.newContext()
  const sender = await senderContext.newPage(), receiver = await receiverContext.newPage()
  try {
    await sender.addInitScript(() => {
      const Base = window.AudioContext
      window.AudioContext = class extends Base {
        constructor(options?: AudioContextOptions) { super({ ...options, sampleRate: 48000 }) }
      }
    })
    for (const page of [sender, receiver]) {
      await page.goto('/tests/audio/fixture.html')
      await page.waitForFunction(() => 'microphoneJoinGate' in window && 'livekitAudioGate' in window)
    }
    await receiver.evaluate(() => (window as any).livekitAudioGate.receiver())
    const joined = await sender.evaluate(() => (window as any).microphoneJoinGate.join('auto', false))
    expect(joined, JSON.stringify(joined)).toMatchObject({ microphone: 'PUBLISHED', publications: 1, enabledAtPublish: [false],
      processingState: { requestedMode: 'auto', effectiveMode: engine, status: 'active' } })
    await expect.poll(async () => {
      const value = await receiver.evaluate(() => (window as any).livekitAudioGate.read())
      return value.readings.some((reading: any) => reading.rms > .001 && reading.nonfinite === 0)
    }, { timeout: 15000 }).toBe(true)
    await sender.evaluate(() => (window as any).microphoneJoinGate.mute())
    await receiver.waitForTimeout(400)
    await receiver.evaluate(() => (window as any).livekitAudioGate.resetMeter())
    await receiver.waitForTimeout(400)
    const muted = await receiver.evaluate(() => (window as any).livekitAudioGate.read())
    expect(muted.readings.length).toBeGreaterThan(0)
    expect(muted.readings.every((r: any) => r.peak < .0001 && r.nonfinite === 0), JSON.stringify(muted.readings)).toBe(true)
  } finally {
    await sender.evaluate(() => (window as any).microphoneJoinGate?.stop()).catch(() => {})
    await receiver.evaluate(() => (window as any).livekitAudioGate?.stop()).catch(() => {})
    await senderContext.close(); await receiverContext.close()
  }
})
