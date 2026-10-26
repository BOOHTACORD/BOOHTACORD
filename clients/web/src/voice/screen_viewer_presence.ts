import { apiBaseUrl } from '../config/runtime'
import { tracedFetch } from '../telemetry/client_tracing'
import { accountIdFromMetadata } from './participant_identity'
import type { ScreenViewerPublication, ScreenViewerWatcher } from './screen_viewer_types'

export type ScreenViewerPresenceRequest = (input: string, init: RequestInit) => Promise<Response>
export const screenViewerHeartbeatMs = 5_000

interface PresencePublication extends ScreenViewerPublication { source?: unknown }
interface PresenceParticipant {
  identity: string
  metadata?: string
  name?: string
  getTrackPublication(source: unknown): PresencePublication | undefined
}
interface PresenceRoom {
  localParticipant?: PresenceParticipant
  remoteParticipants: Map<string, PresenceParticipant>
  on(event: unknown, listener: (...args: any[]) => void): unknown
}
interface PresenceSubscription {
  identity: string
  ownerLeaseId: string
  trackSID: string
  timer: ReturnType<typeof setInterval>
  pending: boolean
  reported?: boolean
  nextWatching?: boolean
}

export interface ScreenViewerPresenceEvents {
  localTrackPublished: unknown
  localTrackUnpublished: unknown
  participantDisconnected: unknown
  trackSubscribed: unknown
  trackUnsubscribed: unknown
}

const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
const trackSID = /^[A-Za-z0-9_-]{1,128}$/

function leaseId(identity: string | undefined): string | null {
  const value = identity?.startsWith('voice-lease:') ? identity.slice('voice-lease:'.length) : ''
  return uuid.test(value) ? value : null
}

function init(method: string, body?: unknown): RequestInit {
  return {
    method, mode: 'same-origin', redirect: 'error', referrerPolicy: 'no-referrer', credentials: 'same-origin', cache: 'no-store',
    headers: { accept: 'application/json', ...(body ? { 'content-type': 'application/json' } : {}) },
    ...(body ? { body: JSON.stringify(body) } : {}),
  }
}

export async function setScreenViewerPresence(viewerLeaseId: string, ownerLeaseId: string, currentTrackSID: string, watching: boolean, request: ScreenViewerPresenceRequest = tracedFetch): Promise<void> {
  if (!uuid.test(viewerLeaseId) || !uuid.test(ownerLeaseId) || !trackSID.test(currentTrackSID)) return
  const path = `${apiBaseUrl}/voice/leases/${encodeURIComponent(viewerLeaseId)}/screen-viewers/${encodeURIComponent(ownerLeaseId)}`
  const target = watching ? path : `${path}?track_sid=${encodeURIComponent(currentTrackSID)}`
  const response = await request(target, watching ? init('PUT', { track_sid: currentTrackSID }) : init('DELETE'))
  if (!response.ok) throw new Error('Не удалось обновить список зрителей трансляции.')
}

export async function clearScreenViewerAudience(ownerLeaseId: string, request: ScreenViewerPresenceRequest = tracedFetch, currentTrackSID?: string): Promise<void> {
  if (!uuid.test(ownerLeaseId)) return
  const query = currentTrackSID && trackSID.test(currentTrackSID) ? `?track_sid=${encodeURIComponent(currentTrackSID)}` : ''
  const response = await request(`${apiBaseUrl}/voice/leases/${encodeURIComponent(ownerLeaseId)}/screen-viewers${query}`, init('DELETE'))
  if (!response.ok) throw new Error('Не удалось очистить список зрителей трансляции.')
}

export async function readScreenViewerAccounts(ownerLeaseId: string, request: ScreenViewerPresenceRequest = tracedFetch): Promise<string[]> {
  if (!uuid.test(ownerLeaseId)) return []
  const response = await request(`${apiBaseUrl}/voice/leases/${encodeURIComponent(ownerLeaseId)}/screen-viewers`, init('GET'))
  return parseScreenViewerAccounts(response)
}

export async function readScreenViewerAccountsForViewer(viewerLeaseId: string, ownerLeaseId: string, request: ScreenViewerPresenceRequest = tracedFetch): Promise<string[]> {
  if (!uuid.test(viewerLeaseId) || !uuid.test(ownerLeaseId)) return []
  const path = `${apiBaseUrl}/voice/leases/${encodeURIComponent(viewerLeaseId)}/screen-viewers/${encodeURIComponent(ownerLeaseId)}`
  return parseScreenViewerAccounts(await request(path, init('GET')))
}

async function parseScreenViewerAccounts(response: Response): Promise<string[]> {
  if (!response.ok) throw new Error('Не удалось обновить список зрителей трансляции.')
  const body = await response.json() as { viewer_account_ids?: unknown }
  if (!Array.isArray(body.viewer_account_ids) || !body.viewer_account_ids.every(value => typeof value === 'string' && uuid.test(value))) {
    throw new Error('Сервер вернул некорректный список зрителей трансляции.')
  }
  return [...new Set(body.viewer_account_ids.map(value => (value as string).toLowerCase()))]
}

function watcher(accountId: string, room: PresenceRoom): ScreenViewerWatcher {
  const participants = [room.localParticipant, ...room.remoteParticipants.values()].filter((value): value is PresenceParticipant => Boolean(value))
  const participant = participants.find(value => accountIdFromMetadata(value.metadata) === accountId)
  return { id: accountId, accountId, name: participant?.name?.trim() || 'Участник' }
}

export class ScreenViewerPresenceController {
  private readonly subscriptions = new Map<string, PresenceSubscription>()
  private audienceRefreshGeneration = 0
  private selectedAudienceOwnerLeaseId: string | null = null
  private selectedAudienceTimer?: ReturnType<typeof setInterval>

  constructor(
    private readonly room: PresenceRoom,
    private readonly events: ScreenViewerPresenceEvents,
    private readonly screenVideoSource: unknown,
    private readonly setWatchers: (watchers: ScreenViewerWatcher[]) => void,
    private readonly request: ScreenViewerPresenceRequest = tracedFetch,
    private readonly heartbeatMs = screenViewerHeartbeatMs,
    private readonly setOwnerWatchers: (watchers: ScreenViewerWatcher[]) => void = () => undefined,
  ) {
    room.on(events.trackSubscribed, this.onTrackSubscribed)
    room.on(events.trackUnsubscribed, this.onTrackUnsubscribed)
    room.on(events.participantDisconnected, this.onParticipantDisconnected)
    room.on(events.localTrackPublished, this.onLocalTrackPublished)
    room.on(events.localTrackUnpublished, this.onLocalTrackUnpublished)
  }

  refreshOwner = async (): Promise<void> => {
    if (this.selectedAudienceOwnerLeaseId) return this.refreshViewedAudience(this.selectedAudienceOwnerLeaseId)
    const owner = this.room.localParticipant
    const ownerLeaseId = leaseId(owner?.identity)
    const publication = owner?.getTrackPublication(this.screenVideoSource)
    const sid = publication && publication.source === this.screenVideoSource ? publication.trackSid : undefined
    const generation = ++this.audienceRefreshGeneration
    if (!ownerLeaseId || !sid) {
      this.setOwnerWatchers([])
      if (!this.selectedAudienceOwnerLeaseId) this.setWatchers([])
      return
    }
    try {
      const accountIds = await readScreenViewerAccounts(ownerLeaseId, this.request)
      if (generation !== this.audienceRefreshGeneration || this.selectedAudienceOwnerLeaseId || this.currentOwnerTrackSID() !== sid) return
      const watchers = accountIds.map(accountId => watcher(accountId, this.room))
      this.setOwnerWatchers(watchers)
      this.setWatchers(watchers)
    } catch { /* Keep the last known audience while the private presence service recovers. */ }
  }

  selectAudience(ownerLeaseId: string | null): Promise<void> {
    const nextOwnerLeaseId = ownerLeaseId && uuid.test(ownerLeaseId) ? ownerLeaseId.toLowerCase() : null
    if (nextOwnerLeaseId === this.selectedAudienceOwnerLeaseId) return this.refreshSelectedAudience()
    this.selectedAudienceOwnerLeaseId = nextOwnerLeaseId
    this.audienceRefreshGeneration += 1
    if (this.selectedAudienceTimer) clearInterval(this.selectedAudienceTimer)
    this.selectedAudienceTimer = undefined
    if (!nextOwnerLeaseId) return this.refreshOwner()
    this.setWatchers([])
    this.selectedAudienceTimer = setInterval(() => { void this.refreshViewedAudience(nextOwnerLeaseId) }, this.heartbeatMs)
    return this.refreshViewedAudience(nextOwnerLeaseId)
  }

  refreshSelectedAudience = async (): Promise<void> => {
    const ownerLeaseId = this.selectedAudienceOwnerLeaseId
    if (ownerLeaseId) return this.refreshViewedAudience(ownerLeaseId)
    return this.refreshOwner()
  }

  clear(): void {
    this.audienceRefreshGeneration += 1
    this.selectedAudienceOwnerLeaseId = null
    if (this.selectedAudienceTimer) clearInterval(this.selectedAudienceTimer)
    this.selectedAudienceTimer = undefined
    for (const [key, subscription] of this.subscriptions) {
      clearInterval(subscription.timer)
      this.send(subscription, false)
      this.subscriptions.delete(key)
    }
    const ownerLeaseId = leaseId(this.room.localParticipant?.identity)
    if (ownerLeaseId) void clearScreenViewerAudience(ownerLeaseId, this.request).catch(() => undefined)
    this.setWatchers([])
    this.setOwnerWatchers([])
  }

  private readonly onTrackSubscribed = (_track: unknown, publication: PresencePublication, participant: PresenceParticipant): void => {
    if (publication.source !== this.screenVideoSource || !publication.trackSid || !trackSID.test(publication.trackSid)) return
    const viewerLeaseId = leaseId(this.room.localParticipant?.identity)
    const ownerLeaseId = leaseId(participant.identity)
    if (!viewerLeaseId || !ownerLeaseId) return
    const key = `${participant.identity}:${publication.trackSid}`
    if (this.subscriptions.has(key)) return
    const subscription: PresenceSubscription = {
      identity: participant.identity, ownerLeaseId, trackSID: publication.trackSid, timer: undefined as unknown as ReturnType<typeof setInterval>, pending: false,
    }
    subscription.timer = setInterval(() => this.send(subscription, true), this.heartbeatMs)
    this.subscriptions.set(key, subscription)
    this.send(subscription, true)
  }

  private readonly onTrackUnsubscribed = (_track: unknown, publication: PresencePublication, participant: PresenceParticipant): void => {
    if (publication.source !== this.screenVideoSource || !publication.trackSid) return
    const key = `${participant.identity}:${publication.trackSid}`
    const subscription = this.subscriptions.get(key)
    if (!subscription) return
    clearInterval(subscription.timer)
    this.subscriptions.delete(key)
    this.send(subscription, false)
    if (this.selectedAudienceOwnerLeaseId === subscription.ownerLeaseId) this.setWatchers([])
  }

  private readonly onParticipantDisconnected = (participant: PresenceParticipant): void => {
    for (const [key, subscription] of this.subscriptions) {
      if (subscription.identity !== participant.identity) continue
      clearInterval(subscription.timer)
      this.subscriptions.delete(key)
      this.send(subscription, false)
    }
  }

  private readonly onLocalTrackPublished = (publication: PresencePublication): void => {
    if (publication.source === this.screenVideoSource) void this.refreshSelectedAudience()
  }

  private readonly onLocalTrackUnpublished = (publication: PresencePublication): void => {
    if (publication.source !== this.screenVideoSource) return
    const ownerLeaseId = leaseId(this.room.localParticipant?.identity)
    if (ownerLeaseId) void clearScreenViewerAudience(ownerLeaseId, this.request, publication.trackSid).catch(() => undefined)
    this.setOwnerWatchers([])
    void this.refreshSelectedAudience()
  }

  private currentOwnerTrackSID(): string | undefined {
    const publication = this.room.localParticipant?.getTrackPublication(this.screenVideoSource)
    return publication && publication.source === this.screenVideoSource ? publication.trackSid : undefined
  }

  private async refreshViewedAudience(ownerLeaseId: string): Promise<void> {
    const viewerLeaseId = leaseId(this.room.localParticipant?.identity)
    const generation = ++this.audienceRefreshGeneration
    if (!viewerLeaseId || this.selectedAudienceOwnerLeaseId !== ownerLeaseId) { this.setWatchers([]); return }
    try {
      const accountIds = await readScreenViewerAccountsForViewer(viewerLeaseId, ownerLeaseId, this.request)
      if (generation !== this.audienceRefreshGeneration || this.selectedAudienceOwnerLeaseId !== ownerLeaseId || leaseId(this.room.localParticipant?.identity) !== viewerLeaseId) return
      this.setWatchers(accountIds.map(accountId => watcher(accountId, this.room)))
    } catch { /* Preserve the current stream's last known audience while the service recovers. */ }
  }

  private send(subscription: PresenceSubscription, watching: boolean): void {
    if (subscription.pending) {
      subscription.nextWatching = watching
      return
    }
    const viewerLeaseId = leaseId(this.room.localParticipant?.identity)
    if (!viewerLeaseId) return
    subscription.pending = true
    const refreshAudienceAfterReport = watching && !subscription.reported
    void setScreenViewerPresence(viewerLeaseId, subscription.ownerLeaseId, subscription.trackSID, watching, this.request)
      .then(() => {
        if (watching) subscription.reported = true
        if (refreshAudienceAfterReport && this.selectedAudienceOwnerLeaseId === subscription.ownerLeaseId) void this.refreshViewedAudience(subscription.ownerLeaseId)
      })
      .catch(() => undefined)
      .finally(() => {
        subscription.pending = false
        const next = subscription.nextWatching
        subscription.nextWatching = undefined
        if (next !== undefined && next !== watching) this.send(subscription, next)
      })
  }
}

export function bindLiveKitScreenViewerPresence(
  room: PresenceRoom,
  events: ScreenViewerPresenceEvents,
  screenVideoSource: unknown,
  setWatchers: (watchers: ScreenViewerWatcher[]) => void,
  request?: ScreenViewerPresenceRequest,
  heartbeatMs = screenViewerHeartbeatMs,
  setOwnerWatchers?: (watchers: ScreenViewerWatcher[]) => void,
): ScreenViewerPresenceController {
  return new ScreenViewerPresenceController(room, events, screenVideoSource, setWatchers, request, heartbeatMs, setOwnerWatchers)
}
