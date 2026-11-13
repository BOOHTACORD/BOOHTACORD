import { LocalAudioTrack } from 'livekit-client'
import { LiveKitMicrophoneAdapter } from '../../src/voice/noise_suppression/microphone_adapter/controller'
import { RnnoiseTrackProcessor } from '../../src/voice/noise_suppression/rnnoise_track_processor'

export async function runAdapterRecapture() {
  const context = new AudioContext({ sampleRate: 48000 })
  await context.resume()
  const events: string[] = []
  const captures: MediaStreamTrack[] = []
  const adapter = new LiveKitMicrophoneAdapter({
    async createTrack(options) {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: options })
      const track = stream.getAudioTracks()[0]
      captures.push(track)
      events.push(`capture:${String(track.getSettings().noiseSuppression)}`)
      return new LocalAudioTrack(track, options, true, context)
    },
    async publishTrack(track) { events.push(`publish:${String(track.mediaStreamTrack.enabled)}`) },
    async unpublishTrack() { events.push('unpublish') },
    createProcessor(callbacks) { return new RnnoiseTrackProcessor(callbacks) },
  })
  const browser = { noiseSuppressionMode: 'browser', autoGainControl: false, echoCancellation: false } as const
  const rnnoise = { ...browser, noiseSuppressionMode: 'rnnoise' } as const
  try {
    await adapter.setEnabled(true, browser)
    await adapter.setProcessing(rnnoise)
    const active = adapter.runtimeState
    await adapter.setEnabled(false, rnnoise)
    return { events, active, muted: adapter.readOutputTrack()?.enabled === false,
      oldStopped: captures[0].readyState === 'ended' }
  } finally {
    await adapter.dispose()
    await context.close()
  }
}
