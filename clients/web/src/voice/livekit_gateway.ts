import type { NoiseSuppressionRuntimeState } from './noise_suppression/types'
import type { BrowserAudioProcessingSettings } from './audio_processing_diagnostics'
import { BoundedVoiceReconnectPolicy } from './bounded_voice_reconnect_policy'
import {
  adaptiveMediaRoomOptions,
  type AudioProcessingOptions,
  type MicrophonePublishOptions,
  type MicrophoneState,
} from './media_publishing'
import type { RemoteVoicePlaybackController } from './livekit_screen_viewer_adapter'
import type { RemoteParticipantController } from './remote_participant_controller'
import { ScreenViewerController } from './screen_viewer_controller'
import type { ScreenDiagnostics } from './screen_diagnostics'
import type { VoiceConnectionStats } from './voice_connection_quality'
import type { AudioInputSelection } from './audio_input_selection'
import type { VoiceAudioDiagnostics } from './audio_diagnostics/model'
import type { NetworkDiagnostics } from './network_diagnostics/model'
import type { LocalVideoTrack } from 'livekit-client'
import type { ScreenPublisherPort } from './screen_publisher/types'
import type { ScreenProfile } from './screen_profile/policy'
import type { ScreenTelemetryPublicationScope } from './screen_sender_telemetry'
import type { BrowserVoiceConnectionState } from './browser_resume/lifecycle'

export {
  readScreenShareDiagnostics,
  applyMicrophoneProcessing,
  defaultAudioProcessing,
  microphoneConstraints,
  setMicrophone,
  adaptiveMediaRoomOptions,
  type AudioProcessingOptions,
  type MicrophonePublishOptions,
  type MicrophoneState,
} from './media_publishing'
export type { ScreenProfile } from './screen_profile/policy'

export interface VoiceRoom {
  connect(url: string, token: string, options?: { autoSubscribe?: boolean }): Promise<void>
  disconnect(): Promise<void>
  bindScreenPreviewLease?(leaseId: string): Promise<void> | void
  publishScreenProfileMetadata?(profile: ScreenProfile, mode?: 'motion' | 'text'): Promise<void>
  clearScreenProfileMetadata?(): Promise<void>
  readScreenTelemetryScope?(): ScreenTelemetryPublicationScope | undefined
  stopScreenPreview?(): Promise<void>
  applyScreenPreview?(leaseId: string, bytes: Uint8Array): void
  clearScreenPreview?(leaseId: string): void
  on(event: 'reconnecting' | 'reconnected' | 'disconnected', listener: (reason?: number) => void): VoiceRoom
  readScreenDiagnostics?(): Promise<ScreenDiagnostics>
  stopScreenProfileChecks?(): void
  adoptScreenProfile?(profile: ScreenProfile): void
  screenPublisher?: ScreenPublisherPort<LocalVideoTrack>
  readVoiceConnectionStats?(): Promise<VoiceConnectionStats>
  readVoiceAudioDiagnostics?(): Promise<VoiceAudioDiagnostics>
  readNetworkDiagnostics?(): Promise<NetworkDiagnostics>
  participantCards?: RemoteParticipantController
  remoteVoices?: RemoteVoicePlaybackController
  screenViewer?: ScreenViewerController
  setDeafened?(deafened: boolean): Promise<void> | void
  setMicrophone?(enabled: boolean, options: AudioProcessingOptions): Promise<void>
  disposeMicrophone?(): Promise<void>
  readMicrophoneTrack?(): MediaStreamTrack | undefined
  readAudioInputSelection?(): AudioInputSelection
  readConnectionState?(): BrowserVoiceConnectionState
  readAudioPlaybackAllowed?(): boolean
  startAudioPlayback?(): Promise<void>
  onAudioPlaybackStatusChanged?(listener: (allowed: boolean) => void): () => void
  onAudioInputSelection?(listener: (selection: AudioInputSelection) => void): () => void
  readNoiseSuppressionState?(): NoiseSuppressionRuntimeState
  onNoiseSuppressionState?(listener: (state: NoiseSuppressionRuntimeState) => void): () => void
  applyMicrophoneProcessing?(options: AudioProcessingOptions): Promise<void>
  readAudioProcessingSettings?(): BrowserAudioProcessingSettings | undefined
  switchActiveDevice(kind: 'audioinput' | 'audiooutput', deviceId: string): Promise<boolean>
  localParticipant: {
    setMicrophoneEnabled(enabled: boolean, options: MediaTrackConstraints, publishOptions?: MicrophonePublishOptions): Promise<unknown>
  }
}

export type VoiceRoomFactory = () => VoiceRoom | Promise<VoiceRoom>
export { BoundedVoiceReconnectPolicy }
export { wireLiveKitRoom } from './livekit_room_factory'

export interface JoinedVoiceRoom {
  microphone: MicrophoneState
  room: VoiceRoom
}

export type VoiceJoinMode = 'with-microphone' | 'listener'

export { connectLiveKitRoom, connectLiveKitRoomWithProcessing } from './room_admission/connect'
