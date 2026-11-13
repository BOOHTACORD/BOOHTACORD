import { expect, test } from '@playwright/test'

test('experimental DeepFilter worklet processes and mutes synthetic audio', async ({ page }) => {
  await page.goto('/tests/audio/fixture.html')
  const result = await page.evaluate(async () => {
    const root = '/audio/dfn-research'
    const [bytes, model] = await Promise.all([
      fetch(`${root}/dfn_bg.wasm`).then(response => response.arrayBuffer()),
      fetch(`${root}/model.bin`).then(response => response.arrayBuffer()),
    ])
    const module = await WebAssembly.compile(bytes)
    const helper = '/tests/audio/audio_context_fixture.ts'
    const { resumeAudio } = await import(/* @vite-ignore */ helper)
    const context = new AudioContext({ sampleRate: 48000 }); await resumeAudio(context)
    const oscillator = context.createOscillator(), gain = context.createGain()
    oscillator.frequency.value = 440; gain.gain.value = .2; oscillator.connect(gain)
    const readings: { rms: number; peak: number; nonfinite: number }[] = [], errors: string[] = []
    let node: AudioWorkletNode | undefined, started = false
    try {
      await context.audioWorklet.addModule('/tests/audio/meter.worklet.js')
      await context.audioWorklet.addModule(`${root}/deepfilter/worklet.js`)
      node = new AudioWorkletNode(context, 'boohtacord-deepfilter-research', {
        numberOfInputs: 1, numberOfOutputs: 1, outputChannelCount: [1], channelCount: 1,
        processorOptions: { module, model, attenuation: 25, entropy: crypto.getRandomValues(new Uint8Array(65536)) },
      })
      const messages: any[] = []
      node.port.onmessage = event => { messages.push(event.data); if (event.data.type === 'error') errors.push(event.data.reason) }
      const waitFor = async (type: string, intent?: number) => {
        const deadline = performance.now() + 15000
        while (!messages.some(message => message.type === type && (intent === undefined || message.intent === intent))) {
          if (performance.now() > deadline || errors.length) throw new Error(`Worklet ${type} unavailable`)
          await new Promise(resolve => setTimeout(resolve, 20))
        }
      }
      const meter = new AudioWorkletNode(context, 'rnnoise-test-meter')
      meter.port.onmessage = event => readings.push(event.data)
      gain.connect(node); node.connect(meter); meter.connect(context.destination); oscillator.start(); started = true
      await waitFor('ready'); node.port.postMessage({ type: 'unmute', intent: 7 }); await waitFor('unmuted', 7)
      await new Promise(resolve => setTimeout(resolve, 1400)); const active = readings.splice(0)
      node.port.postMessage({ type: 'mute' }); await new Promise(resolve => setTimeout(resolve, 400))
      readings.length = 0; await new Promise(resolve => setTimeout(resolve, 400)); const muted = readings.splice(0)
      gain.gain.value = 0
      node.port.postMessage({ type: 'unmute', intent: 8 }); await waitFor('unmuted', 8)
      // Drain asynchronous meter messages queued before the reset acknowledgement.
      await new Promise(resolve => setTimeout(resolve, 200))
      readings.length = 0; await new Promise(resolve => setTimeout(resolve, 400)); const afterUnmute = readings.splice(0)
      node.port.postMessage({ type: 'destroy' }); await waitFor('destroyed')
      meter.disconnect(); meter.port.close()
      return { active, muted, afterUnmute, errors }
    } finally { if (started) oscillator.stop(); node?.disconnect(); node?.port.close(); gain.disconnect(); await context.close() }
  })
  expect(result.active.some(reading => reading.rms > .001)).toBe(true)
  expect(result.active.every(reading => reading.nonfinite === 0 && reading.peak <= 1)).toBe(true)
  expect(result.muted.length).toBeGreaterThan(0)
  expect(result.muted.every(reading => reading.peak === 0)).toBe(true)
  expect(result.afterUnmute.length).toBeGreaterThan(0)
  expect(result.afterUnmute.every(reading => reading.peak < .00001)).toBe(true)
  expect(result.errors).toEqual([])
})

test('invalid model fails closed without raw-audio passthrough', async ({ page }) => {
  await page.goto('/tests/audio/fixture.html')
  const result = await page.evaluate(async () => {
    const root = '/audio/dfn-research'
    const module = await WebAssembly.compile(await (await fetch(`${root}/dfn_bg.wasm`)).arrayBuffer())
    const helper = '/tests/audio/audio_context_fixture.ts'
    const { resumeAudio } = await import(/* @vite-ignore */ helper)
    const context = new AudioContext({ sampleRate: 48000 }); await resumeAudio(context)
    const oscillator = context.createOscillator(), gain = context.createGain(), readings: { peak: number }[] = []
    oscillator.connect(gain); gain.gain.value = .2
    let node: AudioWorkletNode | undefined, started = false
    try {
      await context.audioWorklet.addModule('/tests/audio/meter.worklet.js')
      await context.audioWorklet.addModule(`${root}/deepfilter/worklet.js`)
      node = new AudioWorkletNode(context, 'boohtacord-deepfilter-research', {
        outputChannelCount: [1], processorOptions: { module, model: new Uint8Array([1, 2, 3]).buffer,
          attenuation: 25, entropy: crypto.getRandomValues(new Uint8Array(65536)) },
      })
      const messages: any[] = []; node.port.onmessage = event => messages.push(event.data)
      const meter = new AudioWorkletNode(context, 'rnnoise-test-meter')
      meter.port.onmessage = event => readings.push(event.data)
      gain.connect(node); node.connect(meter); meter.connect(context.destination); oscillator.start(); started = true
      await new Promise(resolve => setTimeout(resolve, 1000))
      meter.disconnect(); meter.port.close()
      return { messages, readings }
    } finally { if (started) oscillator.stop(); node?.disconnect(); node?.port.close(); gain.disconnect(); await context.close() }
  })
  expect(result.messages).toContainEqual({ type: 'error', reason: 'initialization' })
  expect(result.readings.length).toBeGreaterThan(0)
  expect(result.readings.every(reading => reading.peak === 0)).toBe(true)
})
