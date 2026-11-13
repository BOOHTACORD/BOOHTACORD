import { expect, test } from '@playwright/test'

test('opt-in adapter prepares a synthetic LiveKit track for mock publication and honors mute', async ({ page }) => {
  await page.goto('/tests/audio/fixture.html')
  const result = await page.evaluate(async () => {
    const adapterPath = '/src/voice/noise_suppression/microphone_adapter/controller.ts'
    const controlsPath = '/src/voice/microphone_processing/processor.ts'
    const dfnPath = '/src/voice/noise_suppression/deepfilter/track_processor.ts'
    const { LiveKitMicrophoneAdapter } = await import(/* @vite-ignore */ adapterPath)
    const { MicrophoneControlsProcessor } = await import(/* @vite-ignore */ controlsPath)
    const { DeepFilterTrackProcessor } = await import(/* @vite-ignore */ dfnPath)
    const livekitPath = '/node_modules/.vite/deps/livekit-client.js'
    const { LocalAudioTrack } = await import(/* @vite-ignore */ livekitPath)
    const context = new AudioContext({ sampleRate: 48000 }); await context.resume()
    await context.audioWorklet.addModule('/tests/audio/meter.worklet.js')
    const oscillator = context.createOscillator(), gain = context.createGain(), capture = context.createMediaStreamDestination()
    oscillator.connect(gain); gain.gain.value = .2; gain.connect(capture); oscillator.start()
    const input = capture.stream.getAudioTracks()[0]
    // Synthetic MediaStreamDestination has no capture-constraint implementation.
    Object.defineProperty(input, 'getSettings', { value: () => ({ noiseSuppression: false }) })
    Object.defineProperty(input, 'applyConstraints', { value: async () => {} })
    let published: any
    const adapter = new LiveKitMicrophoneAdapter({
      createTrack: async () => new LocalAudioTrack(input, {}, true, context),
      publishTrack: async (track: any) => { published = track }, unpublishTrack: async () => {},
      createProcessor: (callbacks: any, options: any) => new MicrophoneControlsProcessor(options.autoGainControl,
        new DeepFilterTrackProcessor({ onFailure: callbacks.onFailure }), () => callbacks.onFailure('processor-error')),
    })
    const options = { autoGainControl: false, echoCancellation: true, noiseSuppressionMode: 'deepfilter' }
    let meter: AudioWorkletNode | undefined, source: MediaStreamAudioSourceNode | undefined
    try {
      await adapter.setEnabled(true, options)
      const state = adapter.runtimeState, track = published.mediaStreamTrack as MediaStreamTrack
      source = context.createMediaStreamSource(new MediaStream([track]))
      meter = new AudioWorkletNode(context, 'rnnoise-test-meter')
      const readings: number[] = []; meter.port.onmessage = event => readings.push(event.data.peak)
      source.connect(meter); meter.connect(context.destination)
      await new Promise(resolve => setTimeout(resolve, 1200))
      const active = readings.some(value => value > .001)
      await adapter.setEnabled(false, options); await new Promise(resolve => setTimeout(resolve, 300))
      readings.length = 0; await new Promise(resolve => setTimeout(resolve, 300))
      return { state, active, muted: !track.enabled && readings.every(value => value === 0) }
    } finally {
      source?.disconnect(); meter?.disconnect(); meter?.port.close(); await adapter.dispose()
      oscillator.stop(); gain.disconnect(); input.stop(); await context.close()
    }
  })
  expect(result.state).toMatchObject({ requestedMode: 'deepfilter', effectiveMode: 'deepfilter', status: 'active' })
  expect(result.active).toBe(true); expect(result.muted).toBe(true)
})
