import { expect, test } from '@playwright/test'

test('experimental track graph handles real browser audio and mute', async ({ page }) => {
  await page.goto('/tests/audio/fixture.html')
  const result = await page.evaluate(async () => {
    const path = '/src/voice/noise_suppression/deepfilter/track_processor.ts'
    const { DeepFilterTrackProcessor } = await import(/* @vite-ignore */ path)
    const helper = '/tests/audio/audio_context_fixture.ts'
    const { resumeAudio } = await import(/* @vite-ignore */ helper)
    const context = new AudioContext({ sampleRate: 48000 }); await resumeAudio(context)
    await context.audioWorklet.addModule('/tests/audio/meter.worklet.js')
    const oscillator = context.createOscillator(), gain = context.createGain(), input = context.createMediaStreamDestination()
    oscillator.connect(gain); gain.gain.value = .2; gain.connect(input); oscillator.start()
    const capture = input.stream.getAudioTracks()[0], errors: string[] = []
    const processor = new DeepFilterTrackProcessor({ onFailure: () => errors.push('failure'), timeoutMs: 30000 })
    const readings: number[] = []
    let source: MediaStreamAudioSourceNode | undefined, meter: AudioWorkletNode | undefined
    try {
      await processor.init({ kind: 'audio', track: capture, audioContext: context })
      const output = processor.processedTrack!
      source = context.createMediaStreamSource(new MediaStream([output]))
      meter = new AudioWorkletNode(context, 'rnnoise-test-meter')
      meter.port.onmessage = event => readings.push(event.data.peak)
      source.connect(meter); meter.connect(context.destination)
      await processor.unmute(); output.enabled = true
      await new Promise(resolve => setTimeout(resolve, 1000))
      const active = readings.some(value => value > .001)
      processor.mute(); await new Promise(resolve => setTimeout(resolve, 300))
      readings.length = 0; await new Promise(resolve => setTimeout(resolve, 300))
      return { active, muted: readings.every(value => value === 0), outputEnabled: output.enabled, errors }
    } finally {
      await processor.destroy(); source?.disconnect(); meter?.disconnect(); meter?.port.close()
      oscillator.stop(); gain.disconnect(); capture.stop(); await context.close()
    }
  })
  // Firefox can stop delivering graph frames entirely when the track is disabled.
  expect(result).toEqual({ active: true, muted: true, outputEnabled: false, errors: [] })
})
