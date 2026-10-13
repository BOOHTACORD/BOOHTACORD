import { screenProfile, type ScreenProfile } from '../screen_profile/policy'
import { SCREEN_DESCRIPTOR_ATTRIBUTE } from './descriptor'
import type { ScreenDescriptorLayer, ScreenDescriptorOwner, ScreenShareDescriptorV1, ScreenProfileMode } from './types'

export interface DescriptorAttributePort { setAttributes(attributes: Record<string, string>): Promise<void> }
export interface CaptureSnapshot { width: number; height: number }
export interface SenderEncodingSnapshot { rid?: string; active?: boolean; maxBitrate?: number; maxFramerate?: number; scaleResolutionDownBy?: number }

export class ScreenProfileMetadataPublisher {
  private mediaSessionId: string | undefined
  private lastProfile: ScreenProfile | undefined
  private lastMode: ScreenProfileMode | undefined
  private lastDescriptor: ScreenShareDescriptorV1 | undefined
  private profileRevision = 0
  private operationRevision = 0

  constructor(
    private readonly participant: DescriptorAttributePort,
    private readonly owner: ScreenDescriptorOwner,
    private readonly createId: () => string = () => crypto.randomUUID(),
  ) {}

  async publish(profile: ScreenProfile, generation: number, capture: CaptureSnapshot, encodings: SenderEncodingSnapshot[], mode: ScreenProfileMode = 'motion'): Promise<void> {
    if (!Number.isSafeInteger(capture.width) || capture.width < 2 || !Number.isSafeInteger(capture.height) || capture.height < 2) {
      throw new Error('Фактический размер захвата экрана недоступен.')
    }
    if (encodings.length < 1 || encodings.length > 2 || encodings.some(encoding =>
      !Number.isFinite(encoding.maxBitrate) || (encoding.maxBitrate ?? 0) < 1 ||
      !Number.isFinite(encoding.maxFramerate) || (encoding.maxFramerate ?? 0) < 1)) {
      throw new Error('Фактические sender encodings демонстрации экрана недоступны.')
    }
    const nextRevision = this.lastProfile === profile && this.lastMode === mode ? this.profileRevision : this.profileRevision + 1
    const nextOperation = this.operationRevision + 1
    this.mediaSessionId ??= this.createId()
    this.operationRevision = nextOperation
    const descriptor = buildDescriptor({
      owner: this.owner, profile, mode, generation, operationRevision: nextOperation, profileRevision: nextRevision,
      mediaSessionId: this.mediaSessionId, capture, encodings,
    })
    this.lastDescriptor = descriptor
    await this.participant.setAttributes({ [SCREEN_DESCRIPTOR_ATTRIBUTE]: JSON.stringify(descriptor) })
    if (this.operationRevision === nextOperation) {
      this.mediaSessionId = descriptor.scope.media_session_id
      this.lastProfile = profile
      this.lastMode = mode
      this.profileRevision = nextRevision
    }
  }

  async clear(): Promise<void> {
    let descriptor: ScreenShareDescriptorV1 | undefined
    if (this.lastDescriptor) {
      descriptor = { ...this.lastDescriptor, scope: { ...this.lastDescriptor.scope, operation_revision: ++this.operationRevision }, publisher_state: 'idle' }
      this.lastDescriptor = descriptor
    }
    this.mediaSessionId = undefined
    this.lastProfile = undefined
    this.lastMode = undefined
    this.profileRevision = 0
    if (descriptor) await this.participant.setAttributes({ [SCREEN_DESCRIPTOR_ATTRIBUTE]: JSON.stringify(descriptor) })
  }
}

function buildDescriptor(input: {
  owner: ScreenDescriptorOwner; profile: ScreenProfile; mode: ScreenProfileMode; generation: number; operationRevision: number; profileRevision: number
  mediaSessionId: string; capture: CaptureSnapshot; encodings: SenderEncodingSnapshot[]
}): ScreenShareDescriptorV1 {
  const target = screenProfile(input.profile)
  const width = input.capture.width, height = input.capture.height
  const captureFps = target.frameRate
  const encodings = input.encodings
  const layers: ScreenDescriptorLayer[] = encodings.map(encoding => {
    const scale = encoding.scaleResolutionDownBy ?? 1
    return {
      rid: encoding.rid ?? null, width: even(width / scale), height: even(height / scale),
      max_fps: encoding.maxFramerate!, max_bitrate_bps: encoding.maxBitrate!,
      scale_down_by: scale, active: encoding.active ?? true,
    }
  })
  return {
    schema_version: 1,
    scope: {
      origin_id: input.owner.originId, account_id: input.owner.accountId, room_id: input.owner.roomId,
      media_session_id: input.mediaSessionId, publication_generation: input.generation, operation_revision: input.operationRevision,
    },
    mode: input.mode, publisher_state: 'sharing', viewer_state: 'idle',
    requested_profile_id: input.profile,
    effective_profile: {
      capture: { max_width: width, max_height: height, max_fps: captureFps },
      encoding: { codec: null, layers },
    },
    layer_topology: layers.length > 1 ? 'bounded-simulcast' : 'single-layer',
    profile_revision: input.profileRevision,
    capabilities: { live_update: true, republish_without_recapture: true, simulcast: layers.length > 1 },
    reason_codes: ['user-request'],
  }
}

function even(value: number): number { return Math.max(2, Math.floor(value / 2) * 2) }
