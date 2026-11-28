import type { ActiveVoiceSession, VoiceConnectionObserver } from '../voice_session_types'
import { bindBrowserVoiceResume, type BrowserVoiceRoom } from './lifecycle'

export function bindVoiceSessionResume(
  joined: ActiveVoiceSession,
  current: () => boolean,
  observer: () => VoiceConnectionObserver | null,
  disconnected: () => Promise<void>,
): (() => void) | undefined {
  const room = joined.room
  if (typeof document === 'undefined' || typeof window === 'undefined' ||
    !room.readConnectionState || !room.readAudioPlaybackAllowed || !room.startAudioPlayback) return

  const browserRoom: BrowserVoiceRoom = {
    readConnectionState: room.readConnectionState,
    readAudioPlaybackAllowed: room.readAudioPlaybackAllowed,
    startAudioPlayback: room.startAudioPlayback,
    onAudioPlaybackStatusChanged: room.onAudioPlaybackStatusChanged,
  }
  return bindBrowserVoiceResume(browserRoom, {
    onMediaState: state => {
      if (!current()) return
      if (state === 'disconnected') void disconnected()
      else if (state === 'reconnecting') observer()?.reconnecting()
      else observer()?.reconnected()
    },
    onAudioPlaybackAllowed: allowed => {
      if (current()) observer()?.audioPlaybackChanged?.(!allowed)
    },
  })
}

export class BrowserVoiceSessionResume {
  private stop?: () => void
  clear(): void { this.stop?.(); this.stop = undefined }
  bind(...args: Parameters<typeof bindVoiceSessionResume>): void {
    this.clear()
    this.stop = bindVoiceSessionResume(...args)
  }
  observe(observer: VoiceConnectionObserver): VoiceConnectionObserver {
    return { ...observer, disconnected: reason => {
      this.clear()
      observer.audioPlaybackChanged?.(false)
      observer.disconnected(reason)
    } }
  }
}
