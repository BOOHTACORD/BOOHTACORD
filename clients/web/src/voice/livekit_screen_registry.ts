import type { ScreenViewerPublication, ScreenViewerStream } from './screen_viewer_controller'
import { isNewerScreenDescriptor, parseScreenDescriptor, SCREEN_DESCRIPTOR_ATTRIBUTE } from './screen_profile_metadata/descriptor'
import { screenDescriptorMetadataEnabled } from './screen_profile_metadata/enabled'
import type { ScreenShareDescriptorV1 } from './screen_profile_metadata/types'

export interface ScreenParticipantPublication {
  accountId?: string
  attributes?: Readonly<Record<string, string>>
  audio?: ScreenViewerPublication
  identity: string
  isLocal?: boolean
  name?: string
  previewLeaseId?: string
  video?: ScreenViewerPublication
}

export class LiveKitScreenRegistry {
  private current: ScreenViewerStream[] = []
  private descriptors = new Map<string, { trackSid?: string; descriptor?: ScreenShareDescriptorV1; floor?: { sessionId: string; generation: number } }>()

  constructor(
    private readonly originId = '',
    private readonly roomId = '',
    private readonly descriptorMetadataEnabled = screenDescriptorMetadataEnabled(),
  ) {}

  refresh(participants: ScreenParticipantPublication[], selectedId: string | null): void {
    const activeIds = new Set(participants.map(participant => participant.identity))
    this.descriptors.forEach((_state, identity) => { if (!activeIds.has(identity)) this.descriptors.delete(identity) })
    this.current = participants.flatMap((participant) => participant.video ? [{
      audio: participant.isLocal ? undefined : participant.audio,
      accountId: participant.accountId,
      descriptor: this.descriptor(participant),
      hasAudio: !participant.isLocal && participant.audio !== undefined,
      id: participant.isLocal ? `local:${participant.identity}:screen` : `${participant.identity}:screen`,
      isLocal: participant.isLocal,
      participantId: participant.identity,
      participantName: participant.isLocal ? 'Ваш экран' : participant.name?.trim() || 'Участник',
      ...this.profile(participant),
      video: participant.video,
    }] : [])
    this.current.filter((stream) => stream.id !== selectedId && !stream.isLocal).forEach((stream) => {
      if (stream.video.isDesired !== false) stream.video.setSubscribed?.(false)
      if (stream.audio?.isDesired !== false) stream.audio?.setSubscribed?.(false)
    })
  }

  streams(): ScreenViewerStream[] {
    return this.current
  }

  private descriptor(participant: ScreenParticipantPublication): ScreenShareDescriptorV1 | undefined {
    if (!this.descriptorMetadataEnabled) {
      this.descriptors.delete(participant.identity)
      return undefined
    }
    const previous = this.descriptors.get(participant.identity)
    const trackSid = participant.video?.trackSid
    const changedTrack = Boolean(previous?.trackSid && trackSid && previous.trackSid !== trackSid)
    const floor = changedTrack && previous?.descriptor
      ? { sessionId: previous.descriptor.scope.media_session_id, generation: previous.descriptor.scope.publication_generation }
      : previous?.floor
    const raw = participant.attributes?.[SCREEN_DESCRIPTOR_ATTRIBUTE]
    const candidate = parseScreenDescriptor(raw, {
      originId: this.originId, roomId: this.roomId, accountId: participant.accountId ?? '',
    })
    const clearsDescriptor = raw === '' || (raw !== undefined && !candidate)
    let descriptor = clearsDescriptor || changedTrack ? undefined : previous?.descriptor
    const clearsFloor = candidate && floor && candidate.scope.media_session_id !== floor.sessionId
    const newerGeneration = candidate && floor && candidate.scope.publication_generation > floor.generation
    if (candidate && (!floor || clearsFloor || newerGeneration) && (!descriptor || isNewerScreenDescriptor(candidate, descriptor))) descriptor = candidate
    this.descriptors.set(participant.identity, { trackSid, descriptor, floor })
    return descriptor
  }

  private profile(participant: ScreenParticipantPublication): Pick<ScreenViewerStream, 'profileSource' | 'targetProfile'> {
    const descriptor = this.descriptors.get(participant.identity)?.descriptor
    if (descriptor) {
      const match = /^P(720|1080|1440)_(15|30|60)$/.exec(descriptor.requested_profile_id)
      return { profileSource: 'sender-metadata', targetProfile: match ? `${match[1]}p · ${match[2]} FPS` : undefined }
    }
    const legacy = screenShareTargetProfile(participant.video?.name)
    return { profileSource: legacy ? 'legacy-track-name' : 'unknown', targetProfile: legacy }
  }
}

export function screenShareTargetProfile(trackName?: string): string | undefined {
  const match = /^screenshare-(720|1080|1440)p-(15|30|60)fps$/.exec(trackName ?? '')
  return match ? `${match[1]}p · ${match[2]} FPS` : undefined
}
