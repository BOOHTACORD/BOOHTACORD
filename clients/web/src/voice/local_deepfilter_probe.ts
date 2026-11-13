import type { Track } from 'livekit-client'
import { deepfilterReleaseEnabled } from './noise_suppression/capabilities'
import { DeepFilterTrackProcessor } from './noise_suppression/deepfilter/track_processor'
import { browserSuppressionDisabled } from './noise_suppression/deepfilter/capture_guard'
import { browserProcessingConstraints, type AudioProcessingOptions, type NoiseSuppressionFallbackReason, type NoiseSuppressionRuntimeState } from './noise_suppression/types'

/** This local test owns its derived track; capture and context remain borrowed. */
export async function prepareLocalDeepFilterProbe(stream: MediaStream, context: AudioContext, processing: AudioProcessingOptions) {
  const source = stream.getAudioTracks()[0]
  let runtime: NoiseSuppressionRuntimeState = { requestedMode: 'deepfilter', effectiveMode: 'unknown', status: 'idle' }
  const fallback = async (reason: NoiseSuppressionFallbackReason) => {
    await source.applyConstraints(browserProcessingConstraints({ ...processing, noiseSuppressionMode: 'browser' }))
    const reported = source.getSettings().noiseSuppression
    runtime = { requestedMode: 'deepfilter', effectiveMode: reported === undefined ? 'unknown' : reported ? 'browser' : 'off', status: 'fallback', fallbackReason: reason }
    return { stream, state: () => runtime, destroy: async () => undefined }
  }
  if (!deepfilterReleaseEnabled()) return fallback('release-disabled')
  if (!browserSuppressionDisabled(source)) return fallback('unsupported')
  const processor = new DeepFilterTrackProcessor({ onFailure: reason => {
    runtime = { requestedMode: 'deepfilter', effectiveMode: 'unknown', status: 'error', fallbackReason: reason }
  } })
  try {
    await processor.init({ kind: 'audio' as Track.Kind.Audio, track: source, audioContext: context })
    if (!processor.processedTrack) throw new Error('Аудиофильтр не предоставил выход.')
    await processor.unmute(); processor.processedTrack.enabled = true
    runtime = { requestedMode: 'deepfilter', effectiveMode: 'deepfilter', status: 'active', modelId: 'deepfilternet3-research-d375b2d' }
    return { stream: new MediaStream([processor.processedTrack]), state: () => runtime, destroy: () => processor.destroy() }
  } catch {
    await processor.destroy()
    return fallback(runtime.fallbackReason ?? 'processor-error')
  }
}
