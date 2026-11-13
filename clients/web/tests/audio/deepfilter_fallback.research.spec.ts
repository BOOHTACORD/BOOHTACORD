import { expect, test } from '@playwright/test'

test('missing DeepFilter asset falls back before mock publication', async ({ page }) => {
  await page.route('**/audio/deepfilternet/research-d375b2d/dfn_bg.wasm', route => route.fulfill({ status: 404, body: '' }))
  await page.goto('/tests/audio/fixture.html')
  const result = await page.evaluate(async () => {
    const adapterPath = '/src/voice/noise_suppression/microphone_adapter/controller.ts'
    const dfnPath = '/src/voice/noise_suppression/deepfilter/track_processor.ts'
    const livekitPath = '/node_modules/.vite/deps/livekit-client.js'
    const { LiveKitMicrophoneAdapter } = await import(/* @vite-ignore */ adapterPath)
    const { DeepFilterTrackProcessor } = await import(/* @vite-ignore */ dfnPath)
    const { LocalAudioTrack } = await import(/* @vite-ignore */ livekitPath)
    const context = new AudioContext({ sampleRate: 48000 }); await context.resume()
    const oscillator = context.createOscillator(), capture = context.createMediaStreamDestination()
    oscillator.connect(capture); oscillator.start()
    const input = capture.stream.getAudioTracks()[0]; let browserNs = false, published = false
    Object.defineProperty(input, 'getSettings', { value: () => ({ noiseSuppression: browserNs }) })
    Object.defineProperty(input, 'applyConstraints', { value: async (constraints: MediaTrackConstraints) => { browserNs = constraints.noiseSuppression === true } })
    const adapter = new LiveKitMicrophoneAdapter({
      createTrack: async () => new LocalAudioTrack(input, {}, true, context),
      publishTrack: async () => { published = true }, unpublishTrack: async () => {},
      createProcessor: (callbacks: any) => new DeepFilterTrackProcessor({ onFailure: callbacks.onFailure }),
    })
    try {
      await adapter.setEnabled(true, { autoGainControl: false, echoCancellation: true, noiseSuppressionMode: 'deepfilter' })
      return { state: adapter.runtimeState, published, browserNs }
    } finally { await adapter.dispose(); oscillator.stop(); input.stop(); await context.close() }
  })
  expect(result.state).toMatchObject({ requestedMode: 'deepfilter', effectiveMode: 'browser', status: 'fallback', fallbackReason: 'asset-load' })
  expect(result.published).toBe(true); expect(result.browserNs).toBe(true)
})
