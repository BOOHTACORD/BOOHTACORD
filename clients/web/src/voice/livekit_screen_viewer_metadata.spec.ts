import { readFileSync } from 'node:fs'
import { afterEach, describe, expect, it, vi } from 'vitest'
import { bindLiveKitScreenViewer, type LiveKitScreenViewerRoom } from './livekit_screen_viewer_adapter'

const fixture = JSON.parse(readFileSync(new URL('../../../../contracts/screen-share-profile-v1.fixtures.json', import.meta.url), 'utf8')).validDescriptor
const accountId = '11111111-1111-4111-8111-111111111111'
const attributeKey = 'boohtacord.screen-share.v1'
const descriptor = (profile: string, operation: number) => JSON.stringify({
  ...fixture,
  requested_profile_id: profile,
  mode: profile.endsWith('_60') ? 'motion' : 'text',
  scope: { ...fixture.scope, origin_id: 'https://app.example.test', account_id: accountId, room_id: 'voice:channel-a', media_session_id: 'session-a', publication_generation: 1, operation_revision: operation },
})

afterEach(() => vi.unstubAllGlobals())

describe('LiveKit screen descriptor metadata events', () => {
  it('reads late-join attributes and refreshes the viewer on newer participant attributes', () => {
    vi.stubGlobal('window', { location: { origin: 'https://app.example.test' } })
    const listeners = new Map<string, (...args: any[]) => void>()
    const video = { trackName: 'screenshare-1080p-30fps', setSubscribed: vi.fn() }
    const participant = {
      identity: 'voice-lease:a', metadata: `account:${accountId}`, name: 'Alice',
      attributes: { [attributeKey]: descriptor('P720_60', 2) },
      getTrackPublication: (source: string) => source === 'screen-video' ? video : undefined,
    }
    const room: LiveKitScreenViewerRoom = {
      name: 'voice:channel-a', on: (_event, listener) => listeners.set(String(_event), listener),
      remoteParticipants: new Map([['alice', participant]]),
    }
    const binding = bindLiveKitScreenViewer(room, {
      activeSpeakersChanged: 'active-speakers-changed', attributesChanged: 'participant-attributes-changed',
      localTrackPublished: 'local-track-published', localTrackUnpublished: 'local-track-unpublished',
      participantConnected: 'participant-connected', participantDisconnected: 'participant-disconnected',
      trackMuted: 'track-muted', trackPublished: 'track-published', trackSubscribed: 'track-subscribed',
      trackUnmuted: 'track-unmuted', trackUnpublished: 'track-unpublished', trackUnsubscribed: 'track-unsubscribed',
    }, { microphone: 'microphone', screenAudio: 'screen-audio', screenVideo: 'screen-video' })

    binding.refresh()
    expect(binding.viewer.cards()[0]).toMatchObject({ targetProfile: '720p · 60 FPS', profileSource: 'sender-metadata' })
    participant.attributes[attributeKey] = descriptor('P1080_60', 3)
    listeners.get('participant-attributes-changed')!({ [attributeKey]: participant.attributes[attributeKey] }, participant)
    expect(binding.viewer.cards()[0]).toMatchObject({ targetProfile: '1080p · 60 FPS', profileSource: 'sender-metadata' })
  })
})
