import { afterEach, describe, expect, it, vi } from 'vitest'

import { captureLocalScreenThumbnails, validScreenThumbnail } from './screen_thumbnail'

afterEach(() => { vi.useRealTimers(); vi.unstubAllGlobals() })

describe('screen thumbnail frames', () => {
  it('accepts only bounded JPEG previews', () => {
    expect(validScreenThumbnail(new Uint8Array([0xff, 0xd8, 0xff, 0xd9]))).toBe(true)
    expect(validScreenThumbnail(new Uint8Array(33 * 1024))).toBe(false)
    expect(validScreenThumbnail(new Uint8Array([1, 2, 3]))).toBe(false)
  })

  it('captures the first preview immediately and refreshes every 30 seconds', async () => {
    vi.useFakeTimers()
    const video = {
      autoplay: false,
      muted: false,
      playsInline: false,
      readyState: 2,
      videoWidth: 1280,
      videoHeight: 720,
      play: vi.fn().mockResolvedValue(undefined),
      pause: vi.fn(),
    } as unknown as HTMLVideoElement
    const context = { drawImage: vi.fn() }
    const toBlob = vi.fn((callback: BlobCallback) => callback(new Blob([new Uint8Array([0xff, 0xd8, 0xff, 0xd9])], { type: 'image/jpeg' })))
    const canvas = {
      width: 0,
      height: 0,
      getContext: vi.fn(() => context),
      toBlob,
    } as unknown as HTMLCanvasElement
    const createElement = vi.fn((tag: string) => (tag === 'video' ? video : canvas))
    vi.stubGlobal('document', { createElement } as unknown as Document)
    const track = { attach: vi.fn(), detach: vi.fn() }
    const onThumbnail = vi.fn()

    const stop = captureLocalScreenThumbnails(track, onThumbnail)
    await vi.advanceTimersByTimeAsync(0)
    expect(onThumbnail).toHaveBeenCalledTimes(1)
    expect(context.drawImage).toHaveBeenCalledWith(video, 0, 0, 480, 270)
    expect(toBlob).toHaveBeenCalledWith(expect.any(Function), 'image/jpeg', 0.6)
    await vi.advanceTimersByTimeAsync(29_999)
    expect(onThumbnail).toHaveBeenCalledTimes(1)
    await vi.advanceTimersByTimeAsync(1)
    expect(onThumbnail).toHaveBeenCalledTimes(2)

    stop()
    expect(track.detach).toHaveBeenCalledWith(video)
    expect(video.pause).toHaveBeenCalledOnce()
  })

  it('retries until the video has its first drawable frame, then waits 30 seconds between updates', async () => {
    vi.useFakeTimers()
    const video = {
      readyState: 0,
      videoWidth: 0,
      videoHeight: 0,
      play: vi.fn().mockResolvedValue(undefined),
      pause: vi.fn(),
    }
    const context = { drawImage: vi.fn() }
    const canvas = {
      width: 0,
      height: 0,
      getContext: vi.fn(() => context),
      toBlob: (callback: BlobCallback) => callback(new Blob([new Uint8Array([0xff, 0xd8, 0xff, 0xd9])], { type: 'image/jpeg' })),
    } as unknown as HTMLCanvasElement
    vi.stubGlobal('document', { createElement: vi.fn((tag: string) => tag === 'video' ? video : canvas) } as unknown as Document)
    const onThumbnail = vi.fn()
    const stop = captureLocalScreenThumbnails({ attach: vi.fn(), detach: vi.fn() }, onThumbnail)

    await vi.advanceTimersByTimeAsync(0)
    expect(onThumbnail).not.toHaveBeenCalled()
    video.readyState = 2
    video.videoWidth = 1280
    video.videoHeight = 720
    await vi.advanceTimersByTimeAsync(1_000)
    expect(onThumbnail).toHaveBeenCalledOnce()
    await vi.advanceTimersByTimeAsync(29_999)
    expect(onThumbnail).toHaveBeenCalledOnce()
    await vi.advanceTimersByTimeAsync(1)
    expect(onThumbnail).toHaveBeenCalledTimes(2)
    stop()
  })

  it('keeps portrait previews within the bounded frame dimensions', async () => {
    vi.useFakeTimers()
    const video = {
      readyState: 2,
      videoWidth: 720,
      videoHeight: 1280,
      play: vi.fn().mockResolvedValue(undefined),
      pause: vi.fn(),
    } as unknown as HTMLVideoElement
    const context = { drawImage: vi.fn() }
    const canvas = {
      width: 0,
      height: 0,
      getContext: vi.fn(() => context),
      toBlob: (callback: BlobCallback) => callback(new Blob([new Uint8Array([0xff, 0xd8, 0xff, 0xd9])], { type: 'image/jpeg' })),
    } as unknown as HTMLCanvasElement
    vi.stubGlobal('document', { createElement: vi.fn((tag: string) => tag === 'video' ? video : canvas) } as unknown as Document)

    const stop = captureLocalScreenThumbnails({ attach: vi.fn(), detach: vi.fn() }, vi.fn())
    await vi.advanceTimersByTimeAsync(0)
    expect(context.drawImage).toHaveBeenCalledWith(video, 0, 0, 180, 320)
    stop()
  })

  it('falls back to a smaller frame when the high-resolution JPEG exceeds the upload cap', async () => {
    vi.useFakeTimers()
    const video = {
      readyState: 2,
      videoWidth: 1280,
      videoHeight: 720,
      play: vi.fn().mockResolvedValue(undefined),
      pause: vi.fn(),
    } as unknown as HTMLVideoElement
    const context = { drawImage: vi.fn() }
    const canvas = { width: 0, height: 0, getContext: vi.fn(() => context) } as unknown as HTMLCanvasElement
    const toBlob = vi.fn((callback: BlobCallback) => {
      const bytes = new Uint8Array(canvas.width > 320 ? 16 * 1024 : 8 * 1024)
      bytes.set([0xff, 0xd8], 0)
      bytes.set([0xff, 0xd9], bytes.length - 2)
      callback(new Blob([bytes], { type: 'image/jpeg' }))
    })
    canvas.toBlob = toBlob
    vi.stubGlobal('document', { createElement: vi.fn((tag: string) => tag === 'video' ? video : canvas) } as unknown as Document)
    const onThumbnail = vi.fn()
    const stop = captureLocalScreenThumbnails({ attach: vi.fn(), detach: vi.fn() }, onThumbnail)

    await vi.advanceTimersByTimeAsync(0)
    expect(toBlob).toHaveBeenCalledTimes(2)
    expect(context.drawImage).toHaveBeenNthCalledWith(2, video, 0, 0, 320, 180)
    expect(onThumbnail.mock.calls[0][0]).toHaveLength(8 * 1024)
    stop()
  })

  it('retains a compact fallback for detailed screens that exceed the upload cap', async () => {
    vi.useFakeTimers()
    const video = {
      readyState: 2,
      videoWidth: 1280,
      videoHeight: 720,
      play: vi.fn().mockResolvedValue(undefined),
      pause: vi.fn(),
    } as unknown as HTMLVideoElement
    const context = { drawImage: vi.fn() }
    const canvas = { width: 0, height: 0, getContext: vi.fn(() => context) } as unknown as HTMLCanvasElement
    const qualities: number[] = []
    const toBlob = vi.fn((callback: BlobCallback, _type?: string, quality?: number) => {
      qualities.push(quality ?? 0)
      const bytes = new Uint8Array(canvas.width > 160 ? 16 * 1024 : 8 * 1024)
      bytes.set([0xff, 0xd8], 0)
      bytes.set([0xff, 0xd9], bytes.length - 2)
      callback(new Blob([bytes], { type: 'image/jpeg' }))
    })
    canvas.toBlob = toBlob
    vi.stubGlobal('document', { createElement: vi.fn((tag: string) => tag === 'video' ? video : canvas) } as unknown as Document)
    const onThumbnail = vi.fn()
    const stop = captureLocalScreenThumbnails({ attach: vi.fn(), detach: vi.fn() }, onThumbnail)

    await vi.advanceTimersByTimeAsync(0)
    expect(toBlob).toHaveBeenCalledTimes(4)
    expect(context.drawImage).toHaveBeenNthCalledWith(4, video, 0, 0, 160, 90)
    expect(qualities[3]).toBe(0.45)
    expect(onThumbnail.mock.calls[0][0]).toHaveLength(8 * 1024)
    stop()
  })
})
