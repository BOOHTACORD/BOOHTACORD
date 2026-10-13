import { Track, type RemoteTrack } from 'livekit-client'
import { readFrameMarker } from './frame_marker'

export class BaselinePresentation {
  private connectedAt = 0
  private videoAttachmentRevision = 0
  private firstFrameLatencyMs: number | null = null
  private firstFrameResolver: ((value: number) => void) | null = null
  private presentedFrameCallbacks = 0
  private presentationTimestamps: number[] = []
  private callbackId: number | null = null
  private remoteTrack: RemoteTrack | null = null
  private video: HTMLVideoElement | null = null
  private markerCanvas = document.createElement('canvas')
  private numberedSource = false
  private presentedFrameIds: Array<number | null> = []
  private timestampCursor = 0
  private frameIdCursor = 0

  start(monotonicMs: number) {
    this.connectedAt = monotonicMs
  }

  attach(track: RemoteTrack, video: HTMLVideoElement, numberedSource = false) {
    if (track.kind !== Track.Kind.Video || this.remoteTrack === track) return
    if (this.remoteTrack) this.stop()
    this.videoAttachmentRevision++
    this.remoteTrack = track
    this.video = video
    this.numberedSource = numberedSource
    track.attach(video)
    void video.play().catch(() => undefined)
    this.observe(video)
  }

  private observe(video: HTMLVideoElement) {
    const next = () => {
      if (typeof video.requestVideoFrameCallback !== 'function') return
      this.callbackId = video.requestVideoFrameCallback(() => {
        const now = performance.now()
        this.presentedFrameCallbacks++
        this.presentationTimestamps.push(now)
        if (this.presentationTimestamps.length > 50000) {
          this.presentationTimestamps.shift()
          this.timestampCursor = Math.max(0, this.timestampCursor - 1)
        }
        if (this.numberedSource) {
          let frameId: number | null = null
          try { frameId = readFrameMarker(video, this.markerCanvas) } catch { /* cross-browser canvas readback may be unavailable */ }
          this.presentedFrameIds.push(frameId)
          if (this.presentedFrameIds.length > 50000) {
            this.presentedFrameIds.shift()
            this.frameIdCursor = Math.max(0, this.frameIdCursor - 1)
          }
        }
        if (this.firstFrameLatencyMs === null) {
          this.firstFrameLatencyMs = now - this.connectedAt
          this.firstFrameResolver?.(this.firstFrameLatencyMs)
          this.firstFrameResolver = null
        }
        next()
      })
    }
    next()
  }

  waitForFirstFrame(timeoutMs: number) {
    if (this.firstFrameLatencyMs !== null) return Promise.resolve(this.firstFrameLatencyMs)
    return new Promise<number>((resolve, reject) => {
      const timeout = window.setTimeout(() => reject(new Error('viewer did not present a frame')), timeoutMs)
      this.firstFrameResolver = value => { window.clearTimeout(timeout); resolve(value) }
    })
  }

  snapshot() {
    const quality = this.video?.getVideoPlaybackQuality()
    const timestamps = this.presentationTimestamps.slice(this.timestampCursor)
    const frameIds = this.presentedFrameIds.slice(this.frameIdCursor)
    this.timestampCursor = this.presentationTimestamps.length
    this.frameIdCursor = this.presentedFrameIds.length
    return {
      videoAttachmentRevision: this.videoAttachmentRevision,
      firstFrameLatencyMs: this.firstFrameLatencyMs,
      presentedFrameCallbacks: this.presentedFrameCallbacks,
      presentationTimestamps: timestamps,
      presentedFrameIds: frameIds,
      playbackQuality: quality ? { totalVideoFrames: quality.totalVideoFrames, droppedVideoFrames: quality.droppedVideoFrames } : null,
    }
  }

  stop() {
    if (this.callbackId !== null) this.video?.cancelVideoFrameCallback(this.callbackId)
    this.remoteTrack?.detach()
    this.video?.pause()
    if (this.video) this.video.srcObject = null
    this.remoteTrack = null
    this.video = null
    this.firstFrameLatencyMs = null
    this.firstFrameResolver = null
    this.presentedFrameCallbacks = 0
    this.presentationTimestamps = []
    this.presentedFrameIds = []
    this.timestampCursor = 0
    this.frameIdCursor = 0
    this.numberedSource = false
  }
}
