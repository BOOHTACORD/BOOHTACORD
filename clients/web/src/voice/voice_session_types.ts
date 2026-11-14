import type { LiveKitCredential, VoiceLease } from './admission_client'
import type { AudioProcessingOptions, JoinedVoiceRoom, ScreenProfile, VoiceJoinMode } from './livekit_gateway'

export interface VoiceAdmission {
  acquire(channelId: string, transfer: boolean): Promise<VoiceLease>
  credential(leaseId: string): Promise<LiveKitCredential>
  release(leaseId: string): Promise<void>
}

export interface ActiveVoiceSession extends JoinedVoiceRoom {
  listenerOnly?: boolean
  microphoneAllowed?: boolean
  channelId: string
  leaseId: string
  screenProfile: ScreenProfile | null
}

export type RoomJoiner = (credential: LiveKitCredential, processing?: AudioProcessingOptions, joinMode?: VoiceJoinMode, inputDeviceId?: string) => Promise<JoinedVoiceRoom>
export interface VoiceConnectionObserver {
  admitted?(leaseID: string, channelID: string): void
  disconnected(reason?: number): void
  reconnected(): void
  reconnecting(): void
}
