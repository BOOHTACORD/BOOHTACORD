import type { RnnoiseTrackProcessor } from '../../src/voice/noise_suppression/rnnoise_track_processor'

export async function checkUnmuteRace(processor: RnnoiseTrackProcessor) {
  for (let i = 0; i < 20; i++) {
    const pending = processor.unmute(); processor.mute(); await pending
    if (processor.processedTrack!.enabled) throw new Error('Muted track enabled')
  }
  await processor.unmute(); processor.processedTrack!.enabled = true
  return { enabled: processor.processedTrack!.enabled }
}
