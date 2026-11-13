import { expect, test } from '@playwright/test'

test('experimental DeepFilter track reaches a loopback WebRTC peer', async ({ page }) => {
  await page.goto('/tests/audio/fixture.html')
  const result = await page.evaluate(async () => {
    const path = '/src/voice/noise_suppression/deepfilter/track_processor.ts'
    const { DeepFilterTrackProcessor } = await import(/* @vite-ignore */ path)
    const context = new AudioContext({ sampleRate: 48000 }); await context.resume()
    await context.audioWorklet.addModule('/tests/audio/meter.worklet.js')
    const source = context.createOscillator(), gain = context.createGain(), capture = context.createMediaStreamDestination()
    source.connect(gain); gain.gain.value = .2; gain.connect(capture); source.start()
    const track = capture.stream.getAudioTracks()[0], errors: string[] = []
    const processor = new DeepFilterTrackProcessor({ onFailure: () => errors.push('failure') })
    const sender = new RTCPeerConnection({ iceServers: [] }), receiver = new RTCPeerConnection({ iceServers: [] })
    sender.onicecandidate = event => { if (event.candidate) void receiver.addIceCandidate(event.candidate) }
    receiver.onicecandidate = event => { if (event.candidate) void sender.addIceCandidate(event.candidate) }
    let output: MediaStreamAudioSourceNode | undefined, meter: AudioWorkletNode | undefined
    const audio = document.createElement('audio'); audio.muted = true; document.body.append(audio)
    const readings: { rms: number; peak: number }[] = []
    receiver.ontrack = event => {
      audio.srcObject = new MediaStream([event.track]); void audio.play()
      output = context.createMediaStreamSource(new MediaStream([event.track]))
      meter = new AudioWorkletNode(context, 'rnnoise-test-meter')
      meter.port.onmessage = message => readings.push(message.data)
      output.connect(meter); meter.connect(context.destination)
    }
    try {
      await processor.init({ kind: 'audio', track, audioContext: context })
      await processor.unmute(); processor.processedTrack!.enabled = true
      sender.addTrack(processor.processedTrack!)
      await sender.setLocalDescription(await sender.createOffer())
      await receiver.setRemoteDescription(sender.localDescription!)
      await receiver.setLocalDescription(await receiver.createAnswer())
      await sender.setRemoteDescription(receiver.localDescription!)
      const deadline = performance.now() + 15000
      while (!readings.some(reading => reading.rms > .001)) {
        if (performance.now() > deadline) throw new Error('remote audio unavailable')
        await new Promise(resolve => setTimeout(resolve, 50))
      }
      processor.mute(); await new Promise(resolve => setTimeout(resolve, 800))
      readings.length = 0; await new Promise(resolve => setTimeout(resolve, 600))
      return { silent: readings.length > 0 && readings.every(reading => reading.peak < .0001), errors }
    } finally {
      sender.close(); receiver.close(); output?.disconnect(); meter?.disconnect(); meter?.port.close(); audio.remove()
      await processor.destroy(); source.stop(); gain.disconnect(); track.stop(); await context.close()
    }
  })
  expect(result).toEqual({ silent: true, errors: [] })
})
