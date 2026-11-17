import { afterEach, describe, expect, it, vi } from 'vitest'

import { VoiceSession, type VoiceAdmission } from '../voice_session'
import type { BrowserVoiceConnectionState } from './lifecycle'

class FakeDocument extends EventTarget {
  visibilityState = 'visible'
}

function admission(): VoiceAdmission {
  return {
    acquire: vi.fn().mockResolvedValue({ id: 'lease-resume', channelId: 'voice-resume', transferred: false }),
    credential: vi.fn().mockResolvedValue({ url: 'wss://rtc.example', token: 'temporary', expiresAt: '2026-11-16T12:00:00Z' }),
    release: vi.fn().mockResolvedValue(undefined),
  }
}

afterEach(() => vi.unstubAllGlobals())

describe('voice session browser resume', () => {
  it('reconciles media separately from page and audio playback state', async () => {
    const documentTarget = new FakeDocument()
    const windowTarget = new EventTarget()
    vi.stubGlobal('document', documentTarget)
    vi.stubGlobal('window', windowTarget)

    let mediaState: BrowserVoiceConnectionState = 'connected'
    let playbackAllowed = true
    const api = admission()
    const room = {
      disconnect: vi.fn().mockResolvedValue(undefined),
      on: vi.fn(),
      readConnectionState: () => mediaState,
      readAudioPlaybackAllowed: () => playbackAllowed,
      startAudioPlayback: vi.fn(async () => { playbackAllowed = true }),
      onAudioPlaybackStatusChanged: (listener: (allowed: boolean) => void) => {
        listener(playbackAllowed)
        return vi.fn()
      },
    }
    const session = new VoiceSession(api, async () => ({ room: room as never, microphone: 'MUTED' }))
    const observer = {
      audioPlaybackChanged: vi.fn(),
      disconnected: vi.fn(),
      reconnected: vi.fn(),
      reconnecting: vi.fn(),
    }
    session.setConnectionObserver(observer)
    await session.join('voice-resume', false, 'listener')

    documentTarget.visibilityState = 'hidden'
    mediaState = 'reconnecting'
    documentTarget.dispatchEvent(new Event('visibilitychange'))
    windowTarget.dispatchEvent(new Event('online'))
    expect(observer.reconnecting).not.toHaveBeenCalled()
    expect(api.acquire).toHaveBeenCalledOnce()

    documentTarget.visibilityState = 'visible'
    documentTarget.dispatchEvent(new Event('visibilitychange'))
    expect(observer.reconnecting).toHaveBeenCalledOnce()

    mediaState = 'connected'
    windowTarget.dispatchEvent(new Event('pageshow'))
    expect(observer.reconnected).toHaveBeenCalledOnce()

    playbackAllowed = false
    windowTarget.dispatchEvent(new Event('online'))
    expect(observer.audioPlaybackChanged).toHaveBeenLastCalledWith(true)
    expect(observer.reconnected).toHaveBeenCalledOnce()
    expect(room.startAudioPlayback).not.toHaveBeenCalled()

    mediaState = 'disconnected'
    windowTarget.dispatchEvent(new Event('pageshow'))
    await vi.waitFor(() => expect(observer.disconnected).toHaveBeenCalledOnce())
    expect(api.release).toHaveBeenCalledWith('lease-resume')
    expect(api.acquire).toHaveBeenCalledOnce()
  })

  it('keeps the active browser resume observer when a stale lease revocation is rejected', async () => {
    const documentTarget = new FakeDocument()
    const windowTarget = new EventTarget()
    vi.stubGlobal('document', documentTarget)
    vi.stubGlobal('window', windowTarget)

    let mediaState: BrowserVoiceConnectionState = 'connected'
    const api = admission()
    const room = {
      disconnect: vi.fn().mockResolvedValue(undefined),
      on: vi.fn(),
      readConnectionState: () => mediaState,
      readAudioPlaybackAllowed: () => true,
      startAudioPlayback: vi.fn(async () => undefined),
    }
    const session = new VoiceSession(api, async () => ({ room: room as never, microphone: 'MUTED' }))
    const observer = { audioPlaybackChanged: vi.fn(), disconnected: vi.fn(), reconnected: vi.fn(), reconnecting: vi.fn() }
    session.setConnectionObserver(observer)
    await session.join('voice-resume', false, 'listener')

    await expect(session.revoke('stale-lease')).resolves.toBe(false)
    mediaState = 'reconnecting'
    windowTarget.dispatchEvent(new Event('pageshow'))

    expect(observer.reconnecting).toHaveBeenCalledOnce()
    expect(api.release).not.toHaveBeenCalled()
  })

  it('cleans up a disconnected room only once when the SDK event races with page resume', async () => {
    const documentTarget = new FakeDocument()
    const windowTarget = new EventTarget()
    vi.stubGlobal('document', documentTarget)
    vi.stubGlobal('window', windowTarget)

    const listeners = new Map<string, (reason?: number) => void>()
    const api = admission()
    let mediaState: BrowserVoiceConnectionState = 'connected'
    const room = {
      disconnect: vi.fn().mockResolvedValue(undefined),
      on: vi.fn((event: string, listener: (reason?: number) => void) => { listeners.set(event, listener) }),
      stopScreenPreview: vi.fn().mockResolvedValue(undefined),
      readConnectionState: () => mediaState,
      readAudioPlaybackAllowed: () => true,
      startAudioPlayback: vi.fn(async () => undefined),
    }
    const session = new VoiceSession(api, async () => ({ room: room as never, microphone: 'MUTED' }))
    const observer = { audioPlaybackChanged: vi.fn(), disconnected: vi.fn(), reconnected: vi.fn(), reconnecting: vi.fn() }
    session.setConnectionObserver(observer)
    await session.join('voice-resume', false, 'listener')

    mediaState = 'disconnected'
    listeners.get('disconnected')?.(7)
    windowTarget.dispatchEvent(new Event('pageshow'))
    await vi.waitFor(() => expect(observer.disconnected).toHaveBeenCalledOnce())

    expect(room.stopScreenPreview).toHaveBeenCalledOnce()
    expect(api.release).toHaveBeenCalledOnce()
    expect(api.release).toHaveBeenCalledWith('lease-resume')
  })
})
