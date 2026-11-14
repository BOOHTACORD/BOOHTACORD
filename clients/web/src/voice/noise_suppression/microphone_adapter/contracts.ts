import type { AudioProcessorOptions, LocalAudioTrack, Track, TrackProcessor } from 'livekit-client'
import { type MicrophonePublishOptions } from '../../media_publishing'
import { type AudioProcessingOptions, type NoiseSuppressionFallbackReason, type NoiseSuppressionRuntimeState } from '../types'

export interface MicrophoneProcessor extends TrackProcessor<Track.Kind.Audio, AudioProcessorOptions> {
  mute(): void
  unmute(): void | Promise<void>
  readonly sourceTrack?: MediaStreamTrack
}
export interface MicrophoneAdapterDependencies {
  preflightAuto?(engine: 'rnnoise' | 'deepfilter'): Promise<boolean>
  createTrack(options: MediaTrackConstraints): Promise<LocalAudioTrack>
  publishTrack(track: LocalAudioTrack, options: MicrophonePublishOptions): Promise<unknown>
  unpublishTrack(track: LocalAudioTrack): Promise<unknown>
  isReconnecting?(): boolean
  createControlsProcessor?(options: AudioProcessingOptions, onFailure: () => void): MicrophoneProcessor
  createProcessor(callbacks: { onFailure(reason: NoiseSuppressionFallbackReason): void; onState(state: NoiseSuppressionRuntimeState): void }, options?: AudioProcessingOptions): MicrophoneProcessor
}
