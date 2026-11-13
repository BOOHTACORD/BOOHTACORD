import type { Track } from 'livekit-client'
import { RnnoiseTrackProcessor } from './noise_suppression/rnnoise_track_processor'
import { prepareLocalDeepFilterProbe } from './local_deepfilter_probe'
import { browserProcessingConstraints, type AudioProcessingOptions, type NoiseSuppressionRuntimeState } from './noise_suppression/types'
export async function prepareLocalMicrophoneProbe(stream: MediaStream, context: AudioContext, processing: AudioProcessingOptions) {
  if (processing.noiseSuppressionMode === 'deepfilter') return prepareLocalDeepFilterProbe(stream, context, processing)
  const source = stream.getAudioTracks()[0]
  let processor: RnnoiseTrackProcessor | undefined
  let runtime: NoiseSuppressionRuntimeState = { requestedMode: processing.noiseSuppressionMode, effectiveMode: 'unknown', status: 'idle' }
  if (processing.noiseSuppressionMode === 'rnnoise') {
    processor = new RnnoiseTrackProcessor({ onState: (state) => { runtime = state } })
    try {
      await processor.init({ kind: 'audio' as Track.Kind.Audio, track: source, audioContext: context })
      if (!processor.processedTrack) throw new Error('Аудиофильтр не предоставил выход.')
      await processor.unmute()
      processor.processedTrack.enabled = true
      return { stream: new MediaStream([processor.processedTrack]), state: () => runtime, destroy: () => processor!.destroy() }
    } catch {
      const reason = runtime.fallbackReason ?? 'processor-error'
      await processor.destroy()
      await source.applyConstraints(browserProcessingConstraints({ ...processing, noiseSuppressionMode: 'browser' }))
      const reported = source.getSettings().noiseSuppression
      runtime = { requestedMode: 'rnnoise', effectiveMode: reported === undefined ? 'unknown' : reported ? 'browser' : 'off', status: 'fallback', fallbackReason: reason }
    }
  }
  return { stream, state: () => runtime, destroy: async () => undefined }
}
