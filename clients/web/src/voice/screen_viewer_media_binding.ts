import { AudioMixer, type AudioGainHandle } from './audio_gain'
import { ScreenTrackAttachment } from './screen_track_attachment'
import type { ScreenViewerStream, ScreenViewerTrack } from './screen_viewer_types'

export interface ScreenViewerBindingChange { changed: boolean; videoChanged: boolean }

export class ScreenViewerMediaBinding {
  private readonly videoBinding = new ScreenTrackAttachment()
  private readonly audioBinding = new ScreenTrackAttachment()
  private audioOutput: AudioGainHandle | null = null
  private videoElement: HTMLVideoElement | null = null
  private audioElement: HTMLAudioElement | null = null

  constructor(private readonly mixer: Pick<AudioMixer, 'attach'> = new AudioMixer()) {}

  bind(stream: ScreenViewerStream | null, video: HTMLVideoElement | null, audio: HTMLAudioElement | null, muted: boolean, volume: number): ScreenViewerBindingChange {
    const videoTargetChanged = this.videoElement !== video
    const audioTargetChanged = this.audioElement !== audio
    if (videoTargetChanged) this.videoBinding.update(null, this.videoElement)
    if (audioTargetChanged) {
      this.audioBinding.update(null, this.audioElement)
      this.disposeAudioOutput()
    }
    this.videoElement = video
    this.audioElement = audio
    const videoChanged = this.videoBinding.update(stream?.video.track ?? null, video)
    const audioTrack = stream && !stream.isLocal ? stream.audio?.track ?? null : null
    const audioChanged = this.audioBinding.update(audioTrack, audio)
    const outputCreated = Boolean(stream && stream.audio && !stream.isLocal && audio && !this.audioOutput && (this.audioOutput = this.mixer.attach(audio)))
    if (stream && !videoTargetChanged && !audioTargetChanged && !videoChanged && !audioChanged && !outputCreated) return { changed: false, videoChanged: false }
    this.audioOutput?.setMuted(muted)
    this.audioOutput?.setVolume(volume)
    const outputDisposed = !stream && this.disposeAudioOutput()
    const changed = videoTargetChanged || audioTargetChanged || videoChanged || audioChanged || outputCreated || outputDisposed
    return { changed, videoChanged: videoTargetChanged || videoChanged }
  }

  reattachVideo(track: ScreenViewerTrack | null, element: HTMLVideoElement | null): boolean {
    if (!track || this.videoBinding.matchesBinding(track, element)) return false
    this.videoBinding.update(track, element)
    return this.videoBinding.matches(track, element)
  }

  hasAttachedVideo(track: ScreenViewerTrack | null, element: HTMLVideoElement | null): boolean {
    return this.videoBinding.matches(track, element)
  }

  setAudioState(muted: boolean, volume: number): void {
    this.audioOutput?.setMuted(muted)
    this.audioOutput?.setVolume(volume)
  }

  detachTracks(): void {
    this.videoBinding.clear()
    this.audioBinding.clear()
  }

  stop(): void {
    this.detachTracks()
    this.disposeAudioOutput()
    this.videoElement = null
    this.audioElement = null
  }

  private disposeAudioOutput(): boolean {
    if (!this.audioOutput) return false
    this.audioOutput?.dispose()
    this.audioOutput = null
    return true
  }
}
