import { expect, test } from '@playwright/test'

test('destroying one experimental worklet leaves the other processing', async ({ page }) => {
  await page.goto('/tests/audio/fixture.html')
  const result = await page.evaluate(async () => {
    const root = '/audio/dfn-research'
    const [wasm, model] = await Promise.all([
      fetch(`${root}/dfn_bg.wasm`).then(r => r.arrayBuffer()),
      fetch(`${root}/model.bin`).then(r => r.arrayBuffer()),
    ])
    const module = await WebAssembly.compile(wasm)
    const context = new AudioContext({ sampleRate: 48000 }); await context.resume()
    await context.audioWorklet.addModule('/tests/audio/meter.worklet.js')
    await context.audioWorklet.addModule(`${root}/deepfilter/worklet.js`)
    const source = context.createOscillator(), gain = context.createGain()
    source.connect(gain); gain.gain.value = .2
    const nodes: AudioWorkletNode[] = [], meters: AudioWorkletNode[] = []
    const messages: any[][] = [[], []], readings: number[][] = [[], []]
    const waitFor = async (index: number, type: string) => {
      const deadline = performance.now() + 15000
      while (!messages[index].some(message => message.type === type)) {
        if (performance.now() > deadline || messages[index].some(m => m.type === 'error')) throw new Error(type)
        await new Promise(resolve => setTimeout(resolve, 20))
      }
    }
    try {
      for (let index = 0; index < 2; index++) {
        const node = new AudioWorkletNode(context, 'boohtacord-deepfilter-research', {
          outputChannelCount: [1], processorOptions: { module, model, attenuation: 25,
            entropy: crypto.getRandomValues(new Uint8Array(65536)) },
        })
        const meter = new AudioWorkletNode(context, 'rnnoise-test-meter')
        node.port.onmessage = event => messages[index].push(event.data)
        meter.port.onmessage = event => readings[index].push(event.data.peak)
        gain.connect(node); node.connect(meter); meter.connect(context.destination)
        nodes.push(node); meters.push(meter)
      }
      source.start()
      await Promise.all([waitFor(0, 'ready'), waitFor(1, 'ready')])
      nodes.forEach(node => node.port.postMessage({ type: 'unmute', intent: 1 }))
      await Promise.all([waitFor(0, 'unmuted'), waitFor(1, 'unmuted')])
      await new Promise(resolve => setTimeout(resolve, 1000))
      const before = readings.map(values => values.some(value => value > .001))
      nodes[0].port.postMessage({ type: 'destroy' }); await waitFor(0, 'destroyed')
      readings[1].length = 0; await new Promise(resolve => setTimeout(resolve, 600))
      return { before, after: readings[1].some(value => value > .001), messages }
    } finally {
      source.stop(); gain.disconnect()
      nodes.forEach(node => { node.port.postMessage({ type: 'destroy' }); node.disconnect(); node.port.close() })
      meters.forEach(meter => { meter.disconnect(); meter.port.close() })
      await context.close()
    }
  })
  expect(result.before).toEqual([true, true])
  expect(result.after).toBe(true)
  expect(result.messages.flat().filter(message => message.type === 'error')).toEqual([])
})
