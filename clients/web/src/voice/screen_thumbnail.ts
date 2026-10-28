const maxBytes = 14 * 1024
const maxThumbnailWidth = 480
const maxThumbnailHeight = 320
const thumbnailScaleFactors = [1, 2 / 3, 1 / 2, 1 / 3, 1 / 4, 1 / 5] as const
const thumbnailQualities = [0.82, 0.74, 0.66, 0.6] as const
const compactThumbnailQuality = 0.45
const initialCaptureRetryIntervalMs = 1_000
const initialCaptureRetryLimit = 10
export const screenThumbnailCaptureIntervalMs = 30_000

export interface LocalScreenThumbnailTrack {
  attach(element: HTMLVideoElement): unknown
  detach(element: HTMLVideoElement): unknown
}

export function validScreenThumbnail(bytes: Uint8Array): boolean {
  return bytes.length >= 4 && bytes.length <= maxBytes &&
    bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[bytes.length - 2] === 0xff && bytes[bytes.length - 1] === 0xd9
}

export function captureLocalScreenThumbnails(
  track: LocalScreenThumbnailTrack,
  onThumbnail: (bytes: Uint8Array) => void,
): () => void {
  const video = document.createElement('video')
  video.autoplay = true
  video.muted = true
  video.playsInline = true
  track.attach(video)
  void video.play().catch(() => undefined)
  let active = true
  let busy = false
  let firstFrameCaptured = false
  let initialRetries = 0
  let timer: ReturnType<typeof setTimeout> | undefined
  const scheduleNext = (delay: number) => {
    if (active) timer = setTimeout(() => { void sample() }, delay)
  }
  async function sample(): Promise<void> {
    if (!active || busy) return
    if (video.readyState < 2 || !video.videoWidth || !video.videoHeight) {
      if (!firstFrameCaptured && initialRetries < initialCaptureRetryLimit) {
        initialRetries += 1
        scheduleNext(initialCaptureRetryIntervalMs)
      } else scheduleNext(screenThumbnailCaptureIntervalMs)
      return
    }
    busy = true
    let captured = false
    try {
      const bytes = await captureVideoFrame(video)
      if (bytes && active) { onThumbnail(bytes); captured = true }
    } catch {
      // A preview failure must not interrupt the live screen track.
    } finally {
      busy = false
      if (captured) { firstFrameCaptured = true; initialRetries = 0 }
      if (!firstFrameCaptured && initialRetries < initialCaptureRetryLimit) {
        initialRetries += 1
        scheduleNext(initialCaptureRetryIntervalMs)
      } else scheduleNext(screenThumbnailCaptureIntervalMs)
    }
  }
  void sample()
  return () => { active = false; if (timer !== undefined) clearTimeout(timer); track.detach(video); video.pause() }
}

async function captureVideoFrame(video: HTMLVideoElement): Promise<Uint8Array | null> {
  const canvas = document.createElement('canvas')
  const context = canvas.getContext('2d')
  if (!context) return null
  const scale = Math.min(1, maxThumbnailWidth / video.videoWidth, maxThumbnailHeight / video.videoHeight)
  const maxWidth = Math.max(1, Math.round(video.videoWidth * scale))
  let blob: Blob | null = null
  const widths = [...new Set(thumbnailScaleFactors.map((factor) => Math.max(1, Math.round(maxWidth * factor))))]
  for (const width of widths) {
    canvas.width = width
    canvas.height = Math.max(1, Math.round(video.videoHeight * width / video.videoWidth))
    context.drawImage(video, 0, 0, canvas.width, canvas.height)
    const qualities = width <= 160 ? [compactThumbnailQuality] : thumbnailQualities
    for (const quality of qualities) {
      blob = await new Promise<Blob | null>((resolve) => canvas.toBlob(resolve, 'image/jpeg', quality))
      if (blob && blob.size <= maxBytes) break
    }
    if (blob && blob.size <= maxBytes) break
  }
  if (!blob || blob.size > maxBytes) return null
  const bytes = new Uint8Array(await blob.arrayBuffer())
  return validScreenThumbnail(bytes) ? bytes : null
}
