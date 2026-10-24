type DisplayCaptureDevices = Pick<MediaDevices, 'getDisplayMedia'>
type WindowAudioOptions = DisplayMediaStreamOptions & { windowAudio?: 'system' | 'window' | 'exclude' }

/**
 * LiveKit's current screen-share options omit the `windowAudio` getDisplayMedia
 * preference. Enrich its next capture request once, then restore the native
 * method immediately so the browser picker never runs while the API is patched.
 */
export async function withWindowAudioPreference<T>(
  capture: () => Promise<T>,
  mediaDevices: DisplayCaptureDevices | undefined = typeof navigator === 'undefined' ? undefined : navigator.mediaDevices,
): Promise<T> {
  if (!mediaDevices || typeof mediaDevices.getDisplayMedia !== 'function') return capture()

  const original = mediaDevices.getDisplayMedia
  const descriptor = Object.getOwnPropertyDescriptor(mediaDevices, 'getDisplayMedia')
  let restored = false
  const restore = () => {
    if (restored) return
    restored = true
    if (descriptor) Object.defineProperty(mediaDevices, 'getDisplayMedia', descriptor)
    else Reflect.deleteProperty(mediaDevices, 'getDisplayMedia')
  }

  const preferredCapture: MediaDevices['getDisplayMedia'] = function (this: MediaDevices, options) {
    restore()
    if (!options?.audio) return original.call(this, options)
    const preferred = { ...options, windowAudio: 'window' } as WindowAudioOptions
    return original.call(this, preferred)
  }

  try {
    Object.defineProperty(mediaDevices, 'getDisplayMedia', {
      configurable: descriptor?.configurable ?? true,
      enumerable: descriptor?.enumerable ?? false,
      writable: descriptor?.writable ?? true,
      value: preferredCapture,
    })
  } catch {
    return capture()
  }

  try {
    return await capture()
  } finally {
    restore()
  }
}
