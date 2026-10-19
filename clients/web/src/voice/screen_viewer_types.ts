import type { TrackPublication } from 'livekit-client'
import type { ScreenShareDescriptorV1 } from './screen_profile_metadata/types'

export interface ScreenViewerTrack {
  receiver?: Pick<RTCRtpReceiver, 'getStats'>
  attach(element: HTMLMediaElement): HTMLMediaElement
  detach(element: HTMLMediaElement): HTMLMediaElement[]
  getReceiverStats?(): Promise<import('./screen_receiver_diagnostics').ScreenReceiverSnapshot | undefined>
}

export interface ScreenViewerPublication {
  isMuted?: boolean
  readonly trackName?: TrackPublication['trackName']
  trackSid?: string
  readonly isDesired?: boolean
  setSubscribed?(subscribed: boolean): void
  track?: ScreenViewerTrack
}

export interface ScreenViewerStream {
  accountId?: string
  audio?: ScreenViewerPublication
  hasAudio: boolean
  id: string
  isLocal?: boolean
  ownerLeaseId?: string
  participantId: string
  participantName: string
  descriptor?: ScreenShareDescriptorV1
  profileSource?: 'sender-metadata' | 'legacy-track-name' | 'unknown'
  targetProfile?: string
  video: ScreenViewerPublication
}

export type ScreenViewerCard = Pick<ScreenViewerStream, 'accountId' | 'descriptor' | 'hasAudio' | 'id' | 'isLocal' | 'ownerLeaseId' | 'participantId' | 'participantName' | 'profileSource' | 'targetProfile'> & {
  thumbnailUrl?: string
  videoMuted?: boolean
  readReceiverStats?: () => Promise<import('./screen_receiver_diagnostics').ScreenReceiverSnapshot | undefined>
}

export interface ScreenViewerWatcher {
  id: string
  accountId?: string
  name: string
}
