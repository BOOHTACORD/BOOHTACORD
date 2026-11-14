import { AudioMixer, normalizeAudioVolume } from './audio_gain'
import { ScreenViewerMediaBinding } from './screen_viewer_media_binding'
import { samePublicationGeneration, setScreenSubscribed } from './screen_viewer_subscription'
import type { ScreenViewerPublication, ScreenViewerStream } from './screen_viewer_types'
export class ScreenViewerLifecycle {
  private readonly media: ScreenViewerMediaBinding
  private selected: ScreenViewerStream | null = null
  private video: HTMLVideoElement | null = null
  private audio: HTMLAudioElement | null = null
  private muted = false
  private volume = 100
  private hasEnded = false
  private operation = 0
  private retryUsed = false
  private readonly automaticRetries = new WeakSet<ScreenViewerPublication>()
  private failedTrackSid: string | null = null
  private stopped = false

  constructor(private readonly source: () => ScreenViewerStream[], mixer: Pick<AudioMixer, 'attach'>, private readonly changed: () => void) { this.media = new ScreenViewerMediaBinding(mixer) }
  get selectedId(): string | null { return this.selected?.id ?? null }
  get selectedAccountId(): string | null { return this.selected?.accountId ?? null }
  get ended(): boolean { return this.hasEnded }
  get audioMuted(): boolean { return this.muted }
  get operationGeneration(): number { return this.operation }
  get subscriptionFailed(): boolean { return this.failedTrackSid !== null }
  hasAttachedVideo(element: HTMLVideoElement | null): boolean { return this.media.hasAttachedVideo(this.selected?.video.track ?? null, element) }
  setAudioMuted(value: boolean): void { this.muted = value; this.applyAudioState(); this.changed() }
  setAudioVolume(value: number): void { this.volume = normalizeAudioVolume(value); this.applyAudioState() }
  markSubscriptionFailed(trackSid: string, participantId: string): boolean {
    if (!this.selected || this.selected.isLocal || this.selected.participantId !== participantId || this.selected.video.trackSid !== trackSid) return false
    this.failedTrackSid = trackSid; this.changed(); return true
  }
  markSubscriptionSucceeded(trackSid: string, participantId: string): boolean { if (!this.selected || this.selected.isLocal || this.selected.participantId !== participantId || this.selected.video.trackSid !== trackSid || this.failedTrackSid !== trackSid) return false; this.failedTrackSid = null; this.changed(); return true }
  clear(): void { if (this.selected || this.hasEnded) this.release(false); this.changed() }
  stop(): void { if (this.stopped) return; this.clear(); this.media.stop(); this.video = null; this.audio = null; this.stopped = true; this.operation += 1 }
  reconcile(): void {
    if (this.stopped) return
    const previous = this.selected
    if (!previous) { this.changed(); return }
    const current = this.source().find((stream) => stream.id === previous.id)
    if (!current || !samePublicationGeneration(previous, current)) { this.release(!previous.isLocal); this.changed(); return }
    const audioChanged = previous.audio !== current.audio
    if (audioChanged && !previous.isLocal) previous.audio?.setSubscribed?.(false)
    this.selected = current
    const binding = this.media.bind(current, this.video, this.audio, this.muted, this.volume)
    if (audioChanged && !current.isLocal) current.audio?.setSubscribed?.(true)
    if (binding.videoChanged) this.operation += 1
    if (binding.changed || audioChanged || previous !== current) this.changed()
  }
  select(id: string | null, video: HTMLVideoElement | null, audio: HTMLAudioElement | null): void {
    if (this.stopped) throw new Error('Просмотр демонстрации уже остановлен.')
    const next = id === null ? null : this.source().find((stream) => stream.id === id)
    if (id !== null && !next) throw new Error('Недоступная демонстрация в текущем голосовом канале.')
    if (next && this.selected && samePublicationGeneration(this.selected, next)) { this.rebind(next, video, audio); return }
    if (this.selected) this.release(false, true)
    if (!next) {
      if (this.hasEnded) this.release(false, true)
      this.video = video
      this.audio = audio
      this.media.bind(null, video, audio, this.muted, this.volume)
      this.changed()
      return
    }
    this.selected = next
    this.video = video; this.audio = audio; this.hasEnded = false; this.retryUsed = false; this.failedTrackSid = null; this.operation += 1
    this.media.bind(next, video, audio, this.muted, this.volume)
    setScreenSubscribed(next, true)
    this.changed()
  }
  rebindElements(video: HTMLVideoElement | null, audio: HTMLAudioElement | null): void {
    if (this.selected) { this.rebind(this.selected, video, audio); return }
    const changed = this.media.bind(null, video, audio, this.muted, this.volume)
    this.video = video; this.audio = audio
    if (changed.videoChanged) this.operation += 1
    if (changed.changed) this.changed()
  }
  retry(automatic = false): boolean {
    const selected = this.selected
    if (!selected || selected.isLocal || this.stopped) return false
    const current = this.source().find((stream) => stream.id === selected.id)
    if (!current || !samePublicationGeneration(selected, current)) { this.reconcile(); return false }
    if (current.video.isMuted) return false
    this.selected = current
    const alreadyRetried = automatic ? this.automaticRetries.has(current.video) : this.retryUsed
    if (alreadyRetried) return false
    if (this.media.reattachVideo(current.video.track ?? null, this.video)) {
      if (automatic) this.automaticRetries.add(current.video); else this.retryUsed = true
      this.failedTrackSid = null; this.operation += 1; this.changed(); return true
    }
    if (!current.video.setSubscribed) return false
    if (automatic) this.automaticRetries.add(current.video); else this.retryUsed = true
    this.failedTrackSid = null; this.operation += 1
    current.video.setSubscribed(false); current.video.setSubscribed(true)
    this.changed()
    return true
  }
  private rebind(next: ScreenViewerStream, video: HTMLVideoElement | null, audio: HTMLAudioElement | null): void {
    const previous = this.selected!
    const audioChanged = previous.audio !== next.audio
    if (audioChanged && !next.isLocal) previous.audio?.setSubscribed?.(false)
    this.selected = next
    const binding = this.media.bind(next, video, audio, this.muted, this.volume)
    this.video = video; this.audio = audio
    if (audioChanged && !next.isLocal) next.audio?.setSubscribed?.(true)
    if (binding.videoChanged) this.operation += 1
    if (binding.changed || audioChanged || previous !== next) this.changed()
  }
  private release(ended: boolean, preserveOutput = false): void {
    const previous = this.selected
    if (previous) { this.media.detachTracks(); setScreenSubscribed(previous, false) }
    this.selected = null; this.hasEnded = ended; this.retryUsed = false; this.failedTrackSid = null; this.operation += 1
    if (!preserveOutput) this.media.bind(null, this.video, this.audio, this.muted, this.volume)
  }
  private applyAudioState(): void { this.media.setAudioState(this.muted, this.volume) }
  }
