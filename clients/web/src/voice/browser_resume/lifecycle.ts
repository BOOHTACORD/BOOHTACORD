export type BrowserVoiceConnectionState = 'connected' | 'reconnecting' | 'disconnected'

export function mediaStateForRoomResume(roomState: string): BrowserVoiceConnectionState {
  if (roomState === 'disconnected') return 'disconnected'
  if (roomState === 'reconnecting' || roomState === 'connecting') return 'reconnecting'
  // LiveKit can reconnect its signaling socket while the media session stays up.
  return 'connected'
}

export interface BrowserVoiceRoom {
  readConnectionState(): BrowserVoiceConnectionState
  readAudioPlaybackAllowed(): boolean
  startAudioPlayback(): Promise<void>
  onAudioPlaybackStatusChanged?(listener: (allowed: boolean) => void): () => void
}

export interface BrowserVoiceResumeObserver {
  onMediaState(state: BrowserVoiceConnectionState): void
  onAudioPlaybackAllowed(allowed: boolean): void
}

interface ResumeEventSource {
  addEventListener(type: string, listener: EventListener): void
  removeEventListener(type: string, listener: EventListener): void
}

interface VisibilityEventSource extends ResumeEventSource {
  visibilityState: string
}

export function bindBrowserVoiceResume(
  room: BrowserVoiceRoom,
  observer: BrowserVoiceResumeObserver,
  documentTarget: VisibilityEventSource = document,
  windowTarget: ResumeEventSource = window,
): () => void {
  let active = true
  let lastMediaState: BrowserVoiceConnectionState | null = null
  const networkTarget = typeof navigator === 'undefined'
    ? undefined
    : (navigator as Navigator & { connection?: ResumeEventSource }).connection

  const refresh = () => {
    if (!active || documentTarget.visibilityState === 'hidden') return

    const mediaState = room.readConnectionState()
    if (mediaState !== lastMediaState) {
      lastMediaState = mediaState
      observer.onMediaState(mediaState)
    }
    observer.onAudioPlaybackAllowed(room.readAudioPlaybackAllowed())
  }
  const onResume = () => refresh()
  const stopAudioObserver = room.onAudioPlaybackStatusChanged?.(allowed => {
    if (active) observer.onAudioPlaybackAllowed(allowed)
  })

  documentTarget.addEventListener('visibilitychange', onResume)
  windowTarget.addEventListener('pageshow', onResume)
  windowTarget.addEventListener('online', onResume)
  windowTarget.addEventListener('offline', onResume)
  networkTarget?.addEventListener('change', onResume)

  return () => {
    if (!active) return
    active = false
    documentTarget.removeEventListener('visibilitychange', onResume)
    windowTarget.removeEventListener('pageshow', onResume)
    windowTarget.removeEventListener('online', onResume)
    windowTarget.removeEventListener('offline', onResume)
    networkTarget?.removeEventListener('change', onResume)
    stopAudioObserver?.()
  }
}

export async function attemptBrowserAudioResume(room: Pick<BrowserVoiceRoom, 'readAudioPlaybackAllowed' | 'startAudioPlayback'>): Promise<boolean> {
  try {
    await room.startAudioPlayback()
    return room.readAudioPlaybackAllowed()
  } catch {
    return false
  }
}
