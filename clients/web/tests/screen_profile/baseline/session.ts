import { type RemoteTrack, type Room } from 'livekit-client'
import { BaselinePresentation } from './presentation'
import { collectSamples, sampleReceiver } from './stats'
import { connectBaselineRoom } from './connection'
import { baselinePlan } from './settings'
import { BaselinePublisher } from './publisher'

type Role = 'publisher' | 'viewer'
type Credentials = { url: string; token: string; role: Role; numberedSynthetic?: boolean }

export class ScreenBaselineSession {
  private credentials: Credentials | null = null
  private room: Room | null = null
  private remoteTrack: RemoteTrack | null = null
  private source = 'none'
  private visibilityRevision = 0
  private metadataPublicationSid: string | null = null
  private metadataPublicationRevision = 0
  private readonly presentation = new BaselinePresentation()
  private readonly publisher: BaselinePublisher

  constructor() {
    this.publisher = new BaselinePublisher(
      () => this.room, () => this.credentials?.role, value => this.setStatus(value),
      async () => { this.setStatus('capture-ended'); await this.stop() },
    )
    document.addEventListener('visibilitychange', () => this.visibilityRevision++)
  }

  configure(credentials: Credentials) {
    this.credentials = credentials
    if (credentials.role === 'viewer') this.source = credentials.numberedSynthetic ? 'synthetic-moving-canvas' : 'remote-display-or-unknown'
  }

  async connect() {
    if (!this.credentials || this.room) throw new Error('baseline session is not ready')
    const credentials = this.credentials
    try {
      await connectBaselineRoom(credentials, this.presentation, room => { this.room = room }, value => this.setStatus(value), track => { this.remoteTrack = track })
      this.setStatus('connected')
    } catch (error) {
      await this.stop()
      this.setStatus('connect-failed')
      throw error
    } finally {
      credentials.token = ''
    }
  }

  startSynthetic(captureFps = 60) { return this.publisher.startSynthetic(captureFps) }
  startDisplayCapture() { return this.publisher.startDisplayCapture() }

  waitForFirstFrame(timeoutMs: number) { return this.presentation.waitForFirstFrame(timeoutMs) }

  async snapshot() {
    const publication = await this.publisher.snapshot()
    return {
      ...publication,
      monotonicMs: performance.now(), role: this.credentials?.role ?? 'unknown',
      source: this.credentials?.role === 'publisher' ? publication.source : this.source,
      baselineProfileId: baselinePlan.profileId,
      visibilityRevision: this.visibilityRevision,
      inbound: await sampleReceiver(this.remoteTrack), ...this.presentation.snapshot(), userAgent: navigator.userAgent,
      visibilityState: document.visibilityState,
    }
  }

  metadataSnapshot(owner: { originId: string; accountId: string; roomId: string }, parse: (raw: string | undefined, owner: { originId: string; accountId: string; roomId: string }) => any) {
    const room = this.room
    const matches = [...(room?.remoteParticipants.values() ?? [])].filter(p => p.metadata === 'account:' + owner.accountId)
    const participant = matches.length === 1 ? matches[0] : undefined
    const publications = [...(participant?.videoTrackPublications.values() ?? [])]
    const sid = publications.length === 1 ? publications[0]?.trackSid : undefined
    const publicationSidChanged = typeof sid === 'string' && this.metadataPublicationSid !== null && sid !== this.metadataPublicationSid
    if (typeof sid === 'string' && sid !== this.metadataPublicationSid) { this.metadataPublicationSid = sid; this.metadataPublicationRevision++ }
    const raw = participant?.attributes['boohtacord.screen-share.v1']
    const descriptor = parse(raw, owner)
    const rejectForeign = ['originId', 'accountId', 'roomId'].every(key => parse(raw, { ...owner, [key]: 'foreign-scope-negative-fixture' }) === undefined)
    const subscriptions = [...(room?.remoteParticipants.values() ?? [])].flatMap(p => [...p.videoTrackPublications.values()]).filter(p => p.isSubscribed).length
    return { publicationObservationRevision: typeof sid === 'string' ? this.metadataPublicationRevision : null, publicationSidChanged, attributePresent: raw !== undefined, descriptorValidForIndependentOwner: descriptor !== undefined, rejectsForeignOwnerScopes: rejectForeign, subscribedVideoCount: subscriptions, descriptor: descriptor ? { schema_version: descriptor.schema_version, mode: descriptor.mode, requested_profile_id: descriptor.requested_profile_id, publisher_state: descriptor.publisher_state, profile_revision: descriptor.profile_revision, publication_generation: descriptor.scope.publication_generation, operation_revision: descriptor.scope.operation_revision, capture: descriptor.effective_profile.capture, codec: descriptor.effective_profile.encoding.codec, layers: descriptor.effective_profile.encoding.layers.map((l: any) => ({ width: l.width, height: l.height, max_fps: l.max_fps, max_bitrate_bps: l.max_bitrate_bps, scale_down_by: l.scale_down_by, active: l.active })) } : null }
  }

  collectSamples(durationMs: number, intervalMs: number) {
    return collectSamples(() => this.snapshot(), durationMs, intervalMs)
  }

  async stop() {
    const room = this.room
    this.room = null
    this.presentation.stop()
    await this.publisher.stop(room)
    this.remoteTrack = null
    await room?.disconnect(true)
    if (this.credentials) this.credentials.token = ''
    this.credentials = null
    this.setStatus('stopped')
  }

  private setStatus(value: string) {
    const status = document.querySelector<HTMLElement>('#status')
    if (status) status.textContent = value
  }
}
