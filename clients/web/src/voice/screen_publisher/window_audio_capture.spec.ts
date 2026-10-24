import { describe, expect, it, vi } from 'vitest'
import { withWindowAudioPreference } from './window_audio_capture'

describe('window audio capture preference', () => {
  it('asks the browser for selected-window audio and restores its capture method immediately', async () => {
    const stream = {} as MediaStream
    let mediaDevices!: MediaDevices
    const getDisplayMedia = vi.fn(function (this: MediaDevices, options?: DisplayMediaStreamOptions) {
      expect(mediaDevices.getDisplayMedia).toBe(getDisplayMedia)
      expect(options).toMatchObject({ audio: true, video: true, windowAudio: 'window' })
      return Promise.resolve(stream)
    })
    mediaDevices = { getDisplayMedia } as unknown as MediaDevices

    await expect(withWindowAudioPreference(
      () => mediaDevices.getDisplayMedia({ audio: true, video: true }), mediaDevices,
    )).resolves.toBe(stream)

    expect(getDisplayMedia).toHaveBeenCalledTimes(1)
    expect(mediaDevices.getDisplayMedia).toBe(getDisplayMedia)
  })

  it('leaves a video-only capture request unchanged', async () => {
    const getDisplayMedia = vi.fn().mockResolvedValue({} as MediaStream)
    const mediaDevices = { getDisplayMedia } as unknown as MediaDevices

    await withWindowAudioPreference(
      () => mediaDevices.getDisplayMedia({ audio: false, video: true }), mediaDevices,
    )

    expect(getDisplayMedia).toHaveBeenCalledWith({ audio: false, video: true })
    expect(mediaDevices.getDisplayMedia).toBe(getDisplayMedia)
  })

  it('restores the capture method when the screen-share operation fails before requesting capture', async () => {
    const getDisplayMedia = vi.fn()
    const mediaDevices = { getDisplayMedia } as unknown as MediaDevices
    const failure = new Error('screen-share setup failed')

    await expect(withWindowAudioPreference(() => Promise.reject(failure), mediaDevices)).rejects.toBe(failure)

    expect(getDisplayMedia).not.toHaveBeenCalled()
    expect(mediaDevices.getDisplayMedia).toBe(getDisplayMedia)
  })

  it('restores the capture method if the browser rejects the selected window', async () => {
    const failure = Object.assign(new Error('picker dismissed'), { name: 'AbortError' })
    const getDisplayMedia = vi.fn().mockRejectedValue(failure)
    const mediaDevices = { getDisplayMedia } as unknown as MediaDevices

    await expect(withWindowAudioPreference(
      () => mediaDevices.getDisplayMedia({ audio: true, video: true }), mediaDevices,
    )).rejects.toBe(failure)

    expect(mediaDevices.getDisplayMedia).toBe(getDisplayMedia)
  })
})
