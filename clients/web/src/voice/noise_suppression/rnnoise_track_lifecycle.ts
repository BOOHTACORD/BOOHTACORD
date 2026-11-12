import type { AudioProcessorOptions, TrackProcessor, Track } from 'livekit-client'
import type { RnnoiseAssets } from './rnnoise_loader'
import type { RnnoiseCounters } from './diagnostics'
import type { NoiseSuppressionFallbackReason, NoiseSuppressionRuntimeState } from './types'

interface RnnoiseProcessorOptions {
  onFailure?: (reason: NoiseSuppressionFallbackReason) => void
  onState?: (state: NoiseSuppressionRuntimeState & Partial<RnnoiseCounters>) => void
  loadAssets?: () => Promise<RnnoiseAssets>
  workletUrl?: string
  initTimeoutMs?: number
}

export abstract class RnnoiseTrackLifecycle implements TrackProcessor<Track.Kind.Audio, AudioProcessorOptions> {
  readonly name = 'rnnoise'
  processedTrack?: MediaStreamTrack
  sourceTrack?: MediaStreamTrack
  runtimeState: NoiseSuppressionRuntimeState & Partial<RnnoiseCounters> = {
    requestedMode: 'rnnoise', effectiveMode: 'unknown', status: 'idle',
  }
  protected source?: MediaStreamAudioSourceNode
  protected destination?: MediaStreamAudioDestinationNode
  protected worklet?: AudioWorkletNode
  protected generation = 0
  protected muted = true
  protected acknowledgeUnmute?: (intent: unknown) => void
  protected cancelUnmute?: () => void
  protected failed = false
  protected cancelInit?: () => void
  constructor(protected readonly options: RnnoiseProcessorOptions = {}) {}
  abstract init(opts: AudioProcessorOptions): Promise<void>
  abstract restart(opts: AudioProcessorOptions): Promise<void>
  protected update(state: Partial<NoiseSuppressionRuntimeState & RnnoiseCounters>): void {
    this.runtimeState = { ...this.runtimeState, ...state }
    this.options.onState?.(this.runtimeState)
  }
  protected fail(reason: NoiseSuppressionFallbackReason): void {
    if (this.failed) return
    this.failed = true
    if (this.processedTrack) this.processedTrack.enabled = false
    this.worklet?.port.postMessage({ type: 'mute' })
    this.update({ status: 'error', effectiveMode: 'unknown', fallbackReason: reason })
    this.options.onFailure?.(reason)
  }
  protected async bounded<T>(operation: Promise<T>): Promise<T> {
    let timer: ReturnType<typeof setTimeout> | undefined
    try {
      return await Promise.race([operation, new Promise<never>((_, reject) => {
        timer = setTimeout(() => reject(new Error('RNNoise preparation timeout')), this.options.initTimeoutMs ?? 8000)
      })])
    } finally { if (timer !== undefined) clearTimeout(timer) }
  }
  protected releaseGraph(): void {
    this.cancelUnmute?.(); this.cancelUnmute = undefined
    this.source?.disconnect(); this.worklet?.disconnect(); this.destination?.disconnect()
    if (this.worklet) {
      this.worklet.onprocessorerror = null
      this.worklet.port.onmessage = null
      this.worklet.port.postMessage({ type: 'destroy' }); this.worklet.port.close()
    }
    this.processedTrack?.stop()
    this.source = undefined; this.worklet = undefined; this.destination = undefined
    this.processedTrack = undefined; this.sourceTrack = undefined
  }
  async destroy(): Promise<void> {
    this.generation++
    this.cancelInit?.(); this.cancelInit = undefined
    this.releaseGraph()
    this.update({ status: 'idle', effectiveMode: 'unknown' })
  }
}
