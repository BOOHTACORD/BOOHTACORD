import { describe, expect, it, vi } from 'vitest'

import { bindLiveKitScreenViewer, type LiveKitScreenViewerRoom } from './livekit_screen_viewer_adapter'
import type { RemoteVoiceTrack } from './remote_voice_playback'

function publication(source?: string) {
  return { isMuted: false, setSubscribed: vi.fn(), source }
}

describe('LiveKit screen viewer adapter', () => {
  it('reads the selected publisher audience using the viewer lease and the publisher lease', async () => {
    const viewerLeaseId = '11111111-1111-4111-8111-111111111111'
    const ownerLeaseId = '22222222-2222-4222-8222-222222222222'
    const viewerAccountId = '33333333-3333-4333-8333-333333333333'
    const ownerAccountId = '44444444-4444-4444-8444-444444444444'
    const video = { ...publication('screen-video'), trackSid: 'TR_owner' }
    const local = { identity: `voice-lease:${viewerLeaseId}`, metadata: `account:${viewerAccountId}`, name: 'Зритель', getTrackPublication: () => undefined }
    const owner = { identity: `voice-lease:${ownerLeaseId}`, metadata: `account:${ownerAccountId}`, name: 'Ведущий', getTrackPublication: (source: string) => source === 'screen-video' ? video : undefined }
    const request = vi.fn(async () => Response.json({ viewer_account_ids: [viewerAccountId] }))
    vi.stubGlobal('fetch', request)
    const room: LiveKitScreenViewerRoom = {
      localParticipant: local,
      on: vi.fn(),
      remoteParticipants: new Map([[owner.identity, owner]]),
    }
    const binding = bindLiveKitScreenViewer(room, {
      activeSpeakersChanged: 'active-speakers-changed', participantConnected: 'participant-connected', participantDisconnected: 'participant-disconnected', localTrackPublished: 'local-track-published', localTrackUnpublished: 'local-track-unpublished', trackMuted: 'track-muted', trackPublished: 'track-published', trackSubscribed: 'track-subscribed', trackUnmuted: 'track-unmuted', trackUnpublished: 'track-unpublished', trackUnsubscribed: 'track-unsubscribed',
    }, { microphone: 'microphone', screenAudio: 'screen-audio', screenVideo: 'screen-video' })

    binding.refresh()
    binding.viewer.select(binding.viewer.cards()[0]!.id, {} as HTMLVideoElement, {} as HTMLAudioElement)
    await vi.waitFor(() => expect(request).toHaveBeenCalledWith(
      `/api/v1/voice/leases/${viewerLeaseId}/screen-viewers/${ownerLeaseId}`,
      expect.objectContaining({ method: 'GET', credentials: 'same-origin', cache: 'no-store' }),
    ))
    await vi.waitFor(() => expect(binding.viewer.watchers()).toEqual([{ id: viewerAccountId, accountId: viewerAccountId, name: 'Зритель' }]))

    binding.clear()
    vi.unstubAllGlobals()
  })

  it('subscribes to room voice while keeping every unselected screen track disabled', () => {
    const microphone = publication('microphone')
    const video = publication('screen-video')
    const audio = publication('screen-audio')
    const listeners = new Map<string, (...arguments_: any[]) => void>()
    const room: LiveKitScreenViewerRoom = {
      on: vi.fn((event: string, listener: (...arguments_: any[]) => void) => listeners.set(event, listener)),
      remoteParticipants: new Map([['alice', {
        identity: 'alice',
        metadata: 'account:22222222-2222-4222-8222-222222222222',
        name: 'Alice',
        getTrackPublication: (source: string) => source === 'microphone' ? microphone : source === 'screen-video' ? video : source === 'screen-audio' ? audio : undefined,
      }]]),
    }
    const binding = bindLiveKitScreenViewer(room, {
      activeSpeakersChanged: 'active-speakers-changed', participantConnected: 'participant-connected', participantDisconnected: 'participant-disconnected', localTrackPublished: 'local-track-published', localTrackUnpublished: 'local-track-unpublished', trackMuted: 'track-muted', trackPublished: 'track-published', trackSubscribed: 'track-subscribed', trackUnmuted: 'track-unmuted', trackUnpublished: 'track-unpublished', trackUnsubscribed: 'track-unsubscribed',
    }, { microphone: 'microphone', screenAudio: 'screen-audio', screenVideo: 'screen-video' })

    binding.subscribeMicrophones()
    binding.refresh()
    listeners.get('track-published')!(microphone)

    expect(microphone.setSubscribed).toHaveBeenCalledWith(true)
    expect(video.setSubscribed).toHaveBeenCalledWith(false)
    expect(audio.setSubscribed).toHaveBeenCalledWith(false)
    expect(binding.viewer.cards()).toEqual([{ accountId: '22222222-2222-4222-8222-222222222222', hasAudio: true, id: '22222222-2222-4222-8222-222222222222:screen', participantId: '22222222-2222-4222-8222-222222222222', participantName: 'Alice', profileSource: 'unknown' }])
    expect(binding.participants.cards()[0]?.microphoneMuted).toBe(false)
    microphone.isMuted = true
    listeners.get('track-muted')!(microphone)
    expect(binding.participants.cards()[0]?.microphoneMuted).toBe(true)
    microphone.isMuted = false
    listeners.get('track-unmuted')!(microphone)
    expect(binding.participants.cards()[0]?.microphoneMuted).toBe(false)
  })

  it('owns remote microphone playback and includes it in deafen cleanup', () => {
    const microphone = publication('microphone')
    const listeners = new Map<string, (...arguments_: any[]) => void>()
    const alice = { identity: 'voice-lease:lease-1', metadata: 'account:11111111-1111-4111-8111-111111111111', getTrackPublication: () => microphone }
    const room: LiveKitScreenViewerRoom = {
      on: vi.fn((event: string, listener: (...arguments_: any[]) => void) => listeners.set(event, listener)),
      remoteParticipants: new Map([['alice', alice]]),
    }
    const playback = { attach: vi.fn(), cards: () => [], clear: vi.fn(), detach: vi.fn(), forget: vi.fn(), isSpeaking: () => false, onChange: () => () => undefined, setDeafened: vi.fn(), setSpeaking: vi.fn(), setVolume: vi.fn() }
    const binding = bindLiveKitScreenViewer(room, {
      activeSpeakersChanged: 'active-speakers-changed', participantConnected: 'participant-connected', participantDisconnected: 'participant-disconnected', localTrackPublished: 'local-track-published', localTrackUnpublished: 'local-track-unpublished', trackMuted: 'track-muted', trackPublished: 'track-published', trackSubscribed: 'track-subscribed', trackUnmuted: 'track-unmuted', trackUnpublished: 'track-unpublished', trackUnsubscribed: 'track-unsubscribed',
    }, { microphone: 'microphone', screenAudio: 'screen-audio', screenVideo: 'screen-video' }, playback)
    const track = {} as RemoteVoiceTrack

    listeners.get('track-subscribed')!(track, microphone, alice)
    binding.setDeafened(true)
    listeners.get('track-unsubscribed')!(track, microphone, alice)
    binding.clear()

    expect(playback.attach).toHaveBeenCalledWith('11111111-1111-4111-8111-111111111111', track, undefined, '11111111-1111-4111-8111-111111111111')
    expect(playback.setDeafened).toHaveBeenCalledWith(true)
    expect(playback.detach).toHaveBeenCalledWith('11111111-1111-4111-8111-111111111111')
    expect(playback.clear).toHaveBeenCalledOnce()
  })

  it('retains a captured preview after unsubscribe and clears it only when the share is unpublished', () => {
    const video = publication('screen-video')
    const alice = { identity: 'alice', metadata: 'account:22222222-2222-4222-8222-222222222222', getTrackPublication: () => video }
    const listeners = new Map<string, (...arguments_: any[]) => void>()
    const room: LiveKitScreenViewerRoom = {
      on: vi.fn((event: string, listener: (...arguments_: any[]) => void) => listeners.set(event, listener)),
      remoteParticipants: new Map([['alice', alice]]),
    }
    const binding = bindLiveKitScreenViewer(room, {
      activeSpeakersChanged: 'active-speakers-changed', participantConnected: 'participant-connected', participantDisconnected: 'participant-disconnected', localTrackPublished: 'local-track-published', localTrackUnpublished: 'local-track-unpublished', trackMuted: 'track-muted', trackPublished: 'track-published', trackSubscribed: 'track-subscribed', trackUnmuted: 'track-unmuted', trackUnpublished: 'track-unpublished', trackUnsubscribed: 'track-unsubscribed',
    }, { microphone: 'microphone', screenAudio: 'screen-audio', screenVideo: 'screen-video' })
    const removeThumbnail = vi.spyOn(binding.viewer, 'removeThumbnail')

    listeners.get('track-unsubscribed')!({}, video, alice)
    expect(removeThumbnail).not.toHaveBeenCalled()
    listeners.get('track-unpublished')!(video, alice)
    expect(removeThumbnail).toHaveBeenCalledWith('22222222-2222-4222-8222-222222222222')
  })

  it('maps LiveKit active speakers to local and remote participants and forgets a departed participant', () => {
    const microphone = publication('microphone')
    const listeners = new Map<string, (...arguments_: any[]) => void>()
    const alice = { identity: 'lease-a', metadata: 'account:11111111-1111-4111-8111-111111111111', getTrackPublication: () => microphone }
    const bob = { identity: 'lease-b', metadata: 'account:22222222-2222-4222-8222-222222222222', getTrackPublication: () => microphone }
    const local = { identity: 'owner-lease', metadata: 'account:33333333-3333-4333-8333-333333333333', getTrackPublication: () => microphone }
    const room: LiveKitScreenViewerRoom = {
      localParticipant: local,
      on: vi.fn((event: string, listener: (...arguments_: any[]) => void) => listeners.set(event, listener)),
      remoteParticipants: new Map([['alice', alice], ['bob', bob]]),
    }
    const playback = { attach: vi.fn(), cards: () => [], clear: vi.fn(), detach: vi.fn(), forget: vi.fn(), isSpeaking: () => false, onChange: () => () => undefined, setDeafened: vi.fn(), setSpeaking: vi.fn(), setVolume: vi.fn() }
    bindLiveKitScreenViewer(room, {
      activeSpeakersChanged: 'active-speakers-changed', participantConnected: 'participant-connected', participantDisconnected: 'participant-disconnected', localTrackPublished: 'local-track-published', localTrackUnpublished: 'local-track-unpublished', trackMuted: 'track-muted', trackPublished: 'track-published', trackSubscribed: 'track-subscribed', trackUnmuted: 'track-unmuted', trackUnpublished: 'track-unpublished', trackUnsubscribed: 'track-unsubscribed',
    }, { microphone: 'microphone', screenAudio: 'screen-audio', screenVideo: 'screen-video' }, playback)

    listeners.get('active-speakers-changed')!([alice, local])
    listeners.get('participant-disconnected')!(alice)

    expect(playback.setSpeaking).toHaveBeenCalledWith('11111111-1111-4111-8111-111111111111', true)
    expect(playback.setSpeaking).toHaveBeenCalledWith('22222222-2222-4222-8222-222222222222', false)
    expect(playback.setSpeaking).toHaveBeenCalledWith('33333333-3333-4333-8333-333333333333', true)
    expect(playback.forget).toHaveBeenCalledWith('11111111-1111-4111-8111-111111111111')
  })

})
