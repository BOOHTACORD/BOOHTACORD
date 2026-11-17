import { describe, expect, it, vi } from 'vitest'

import {
  attemptBrowserAudioResume,
  bindBrowserVoiceResume,
  mediaStateForRoomResume,
  type BrowserVoiceConnectionState,
  type BrowserVoiceRoom,
} from './lifecycle'

class FakeDocument extends EventTarget {
  visibilityState = 'visible'
}

describe('browser voice resume', () => {
  it('does not treat a LiveKit signaling reconnect as a media disconnect', () => {
    expect(mediaStateForRoomResume('signalReconnecting')).toBe('connected')
    expect(mediaStateForRoomResume('reconnecting')).toBe('reconnecting')
    expect(mediaStateForRoomResume('disconnected')).toBe('disconnected')
  })

  it('checks media state and audio permission independently after the page resumes', () => {
    const documentTarget = new FakeDocument()
    const windowTarget = new EventTarget()
    const room: BrowserVoiceRoom = {
      readConnectionState: vi.fn((): BrowserVoiceConnectionState => 'reconnecting'),
      readAudioPlaybackAllowed: vi.fn(() => true),
      startAudioPlayback: vi.fn(async () => undefined),
    }
    const mediaStates: string[] = []
    const playbackStates: boolean[] = []

    const stop = bindBrowserVoiceResume(room, {
      onMediaState: state => mediaStates.push(state),
      onAudioPlaybackAllowed: allowed => playbackStates.push(allowed),
    }, documentTarget, windowTarget)

    documentTarget.visibilityState = 'hidden'
    documentTarget.dispatchEvent(new Event('visibilitychange'))
    windowTarget.dispatchEvent(new Event('online'))
    expect(mediaStates).toEqual([])
    expect(playbackStates).toEqual([])
    expect(room.startAudioPlayback).not.toHaveBeenCalled()

    documentTarget.visibilityState = 'visible'
    documentTarget.dispatchEvent(new Event('visibilitychange'))
    expect(mediaStates).toEqual(['reconnecting'])
    expect(playbackStates).toEqual([true])
    expect(room.startAudioPlayback).not.toHaveBeenCalled()

    stop()
    windowTarget.dispatchEvent(new Event('pageshow'))
    expect(mediaStates).toEqual(['reconnecting'])
  })

  it('unsubscribes from LiveKit playback status when resume observation ends', () => {
    const stopAudioObserver = vi.fn()
    let reportPlaybackAllowed: ((allowed: boolean) => void) | undefined
    const room: BrowserVoiceRoom = {
      readConnectionState: () => 'connected',
      readAudioPlaybackAllowed: () => true,
      startAudioPlayback: vi.fn(async () => undefined),
      onAudioPlaybackStatusChanged: listener => {
        reportPlaybackAllowed = listener
        return stopAudioObserver
      },
    }
    const onAudioPlaybackAllowed = vi.fn()
    const stop = bindBrowserVoiceResume(room, {
      onMediaState: vi.fn(),
      onAudioPlaybackAllowed,
    }, new FakeDocument(), new EventTarget())

    reportPlaybackAllowed?.(false)
    expect(onAudioPlaybackAllowed).toHaveBeenCalledWith(false)
    stop()
    reportPlaybackAllowed?.(true)

    expect(stopAudioObserver).toHaveBeenCalledOnce()
    expect(onAudioPlaybackAllowed).toHaveBeenCalledOnce()
  })

  it('rechecks media after network changes and removes the browser listeners on stop', () => {
    const documentTarget = new FakeDocument()
    const windowTarget = new EventTarget()
    const networkTarget = new EventTarget()
    vi.stubGlobal('navigator', Object.assign(new EventTarget(), { connection: networkTarget }))
    let mediaState: BrowserVoiceConnectionState = 'connected'
    const mediaStates: BrowserVoiceConnectionState[] = []
    const room: BrowserVoiceRoom = {
      readConnectionState: () => mediaState,
      readAudioPlaybackAllowed: () => true,
      startAudioPlayback: vi.fn(async () => undefined),
    }
    const stop = bindBrowserVoiceResume(room, {
      onMediaState: state => mediaStates.push(state),
      onAudioPlaybackAllowed: vi.fn(),
    }, documentTarget, windowTarget)

    documentTarget.visibilityState = 'hidden'
    mediaState = 'reconnecting'
    networkTarget.dispatchEvent(new Event('change'))
    windowTarget.dispatchEvent(new Event('offline'))
    expect(mediaStates).toEqual([])

    documentTarget.visibilityState = 'visible'
    windowTarget.dispatchEvent(new Event('pageshow'))
    expect(mediaStates).toEqual(['reconnecting'])

    mediaState = 'connected'
    networkTarget.dispatchEvent(new Event('change'))
    expect(mediaStates).toEqual(['reconnecting', 'connected'])

    mediaState = 'reconnecting'
    windowTarget.dispatchEvent(new Event('offline'))
    expect(mediaStates).toEqual(['reconnecting', 'connected', 'reconnecting'])

    stop()
    mediaState = 'disconnected'
    networkTarget.dispatchEvent(new Event('change'))
    windowTarget.dispatchEvent(new Event('offline'))
    windowTarget.dispatchEvent(new Event('pageshow'))
    expect(mediaStates).toEqual(['reconnecting', 'connected', 'reconnecting'])
  })

  it('retries blocked room audio only through the explicit user action', async () => {
    let playbackAllowed = false
    const room: BrowserVoiceRoom = {
      readConnectionState: () => 'connected',
      readAudioPlaybackAllowed: () => playbackAllowed,
      startAudioPlayback: vi.fn(async () => { playbackAllowed = true }),
    }

    await expect(attemptBrowserAudioResume(room)).resolves.toBe(true)
    expect(room.startAudioPlayback).toHaveBeenCalledOnce()

    const blockedRoom: BrowserVoiceRoom = {
      ...room,
      readAudioPlaybackAllowed: () => false,
      startAudioPlayback: vi.fn(async () => { throw new Error('autoplay denied') }),
    }
    await expect(attemptBrowserAudioResume(blockedRoom)).resolves.toBe(false)
  })
})
