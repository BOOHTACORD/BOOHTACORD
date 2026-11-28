import type { LiveKitCredential, VoiceLease } from './admission_client'
import type { AudioProcessingOptions, JoinedVoiceRoom, ScreenProfile, VoiceJoinMode } from './livekit_gateway'
import type { VoiceRoomJoinOptions } from './room_admission/intent'

export interface VoiceAdmission {
  acquire(channelId: string, transfer: boolean): Promise<VoiceLease>
  credential(leaseId: string): Promise<LiveKitCredential>
  release(leaseId: string): Promise<void>
}

export interface ActiveVoiceSession extends JoinedVoiceRoom {
  pushToTalk?: boolean
  listenerOnly?: boolean
  microphoneAllowed?: boolean
  channelId: string
  leaseId: string
  screenProfile: ScreenProfile | null
}

export type RoomJoiner = (credential: LiveKitCredential, processing?: AudioProcessingOptions, joinMode?: VoiceJoinMode, inputDeviceId?: string, options?: VoiceRoomJoinOptions) => Promise<JoinedVoiceRoom>
export interface VoiceConnectionObserver {
  admitted?(leaseID: string, channelID: string): void
  audioPlaybackChanged?(blocked: boolean): void
  disconnected(reason?: number): void
  reconnected(): void
  reconnecting(): void
}
