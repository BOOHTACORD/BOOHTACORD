import { AudioMixer } from './audio_gain'
import { createScreenReceiverReader } from './screen_receiver_reader'
import { validScreenThumbnail } from './screen_thumbnail'
import { ScreenViewerLifecycle } from './screen_viewer_lifecycle'
import type { ScreenViewerCard, ScreenViewerStream, ScreenViewerWatcher } from './screen_viewer_types'
export type { ScreenViewerCard, ScreenViewerPublication, ScreenViewerStream, ScreenViewerTrack, ScreenViewerWatcher } from './screen_viewer_types'

export class ScreenViewerController {
  private readonly listeners = new Set<() => void>()
  private readonly lifecycle: ScreenViewerLifecycle
  private readonly receiverReader = createScreenReceiverReader()
  private readonly thumbnailUrls = new Map<string, string>()
  private viewerList: ScreenViewerWatcher[] = []
  private ownerViewerList: ScreenViewerWatcher[] = []
  private watcherRefresh: () => Promise<void> = async () => undefined

  constructor(source: () => ScreenViewerStream[], mixer: Pick<AudioMixer, 'attach'> = new AudioMixer()) {
    this.source = source
    this.lifecycle = new ScreenViewerLifecycle(source, mixer, () => this.notify())
  }

  private readonly source: () => ScreenViewerStream[]

  get selectedId(): string | null { return this.lifecycle.selectedId }
  get selectedAccountId(): string | null { return this.lifecycle.selectedAccountId }
  get ended(): boolean { return this.lifecycle.ended }
  get audioMuted(): boolean { return this.lifecycle.audioMuted }
  get subscriptionFailed(): boolean { return this.lifecycle.subscriptionFailed }
  get operationGeneration(): number { return this.lifecycle.operationGeneration }
  watchers(): ScreenViewerWatcher[] { return this.viewerList.map(watcher => ({ ...watcher })) }
  ownerWatchers(): ScreenViewerWatcher[] { return this.ownerViewerList.map(watcher => ({ ...watcher })) }
  setWatcherRefresh(refresh: () => Promise<void>): void { this.watcherRefresh = refresh }
  refreshWatchers(): Promise<void> { return this.watcherRefresh() }
  hasAttachedVideo(element: HTMLVideoElement | null): boolean { return this.lifecycle.hasAttachedVideo(element) }
  cards(): ScreenViewerCard[] {
    return this.source().map(({ accountId, descriptor, hasAudio, id, isLocal, ownerLeaseId, participantId, participantName, profileSource, targetProfile, video }) => ({
      ...(accountId ? { accountId } : {}), hasAudio, id, ...(isLocal === undefined ? {} : { isLocal }), participantId, participantName,
      ...(ownerLeaseId ? { ownerLeaseId } : {}),
      ...(descriptor ? { descriptor } : {}), ...(profileSource ? { profileSource } : {}),
      ...(targetProfile ? { targetProfile } : {}), ...(video.isMuted === true ? { videoMuted: true } : {}),
      ...(this.thumbnailUrls.get(participantId) ? { thumbnailUrl: this.thumbnailUrls.get(participantId) } : {}),
      ...(!isLocal && video.track?.getReceiverStats ? { readReceiverStats: this.receiverReader(video.track) } : {}),
    }))
  }
  onChange(listener: () => void): () => void { this.listeners.add(listener); return () => this.listeners.delete(listener) }

  setDeafened(deafened: boolean): void { this.lifecycle.setDeafened(deafened) }
  setWatchers(watchers: ScreenViewerWatcher[]): void {
    if (watchers.length === this.viewerList.length && watchers.every((watcher, index) => {
      const previous = this.viewerList[index]
      return previous?.id === watcher.id && previous.accountId === watcher.accountId && previous.name === watcher.name
    })) return
    this.viewerList = watchers
    this.notify()
  }
  setOwnerWatchers(watchers: ScreenViewerWatcher[]): void {
    if (watchers.length === this.ownerViewerList.length && watchers.every((watcher, index) => {
      const previous = this.ownerViewerList[index]
      return previous?.id === watcher.id && previous.accountId === watcher.accountId && previous.name === watcher.name
    })) return
    this.ownerViewerList = watchers
    this.notify()
  }
  setAudioMuted(muted: boolean): void { this.lifecycle.setAudioMuted(muted) }
  setAudioVolume(percent: number): void { this.lifecycle.setAudioVolume(percent) }
  clear(): void { this.clearThumbnails(); this.setWatchers([]); this.lifecycle.clear(); void this.watcherRefresh() }
  stop(): void { this.watcherRefresh = async () => undefined; this.clearThumbnails(); this.setWatchers([]); this.setOwnerWatchers([]); this.lifecycle.stop(); this.listeners.clear() }
  reconcile(): void {
    const previousId = this.selectedId
    this.lifecycle.reconcile()
    if (previousId !== this.selectedId) void this.watcherRefresh()
  }
  select(id: string | null, video: HTMLVideoElement | null, audio: HTMLAudioElement | null): void {
    this.lifecycle.select(id, video, audio)
    void this.watcherRefresh()
  }
  rebindElements(video: HTMLVideoElement | null, audio: HTMLAudioElement | null): void { this.lifecycle.rebindElements(video, audio) }
  retry(automatic = false): boolean { return this.lifecycle.retry(automatic) }
  markSubscriptionFailed(trackSid: string, participantId: string): boolean { return this.lifecycle.markSubscriptionFailed(trackSid, participantId) }
  markSubscriptionSucceeded(trackSid: string, participantId: string): boolean { return this.lifecycle.markSubscriptionSucceeded(trackSid, participantId) }

  setThumbnail(participantId: string, bytes: Uint8Array): void {
    if (!participantId || !validScreenThumbnail(bytes)) return
    const previous = this.thumbnailUrls.get(participantId)
    if (previous) URL.revokeObjectURL(previous)
    this.thumbnailUrls.set(participantId, URL.createObjectURL(new Blob([bytes as BlobPart], { type: 'image/jpeg' })))
    this.notify()
  }

  removeThumbnail(participantId: string): void {
    const previous = this.thumbnailUrls.get(participantId)
    if (!previous) return
    URL.revokeObjectURL(previous)
    this.thumbnailUrls.delete(participantId)
    this.notify()
  }

  private clearThumbnails(): void { for (const url of this.thumbnailUrls.values()) URL.revokeObjectURL(url); this.thumbnailUrls.clear() }
  private notify(): void { this.listeners.forEach((listener) => listener()) }
}
