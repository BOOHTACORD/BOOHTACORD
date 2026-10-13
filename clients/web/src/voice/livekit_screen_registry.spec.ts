import { describe, expect, it, vi } from 'vitest'

import { LiveKitScreenRegistry, type ScreenParticipantPublication } from './livekit_screen_registry'
import { readFileSync } from 'node:fs'

const descriptorFixture = JSON.parse(readFileSync(new URL('../../../../contracts/screen-share-profile-v1.fixtures.json', import.meta.url), 'utf8')).validDescriptor

function publication() {
  return { setSubscribed: vi.fn(), trackName: 'screenshare-1080p-30fps' }
}

function participant(identity: string, video = publication(), audio?: ReturnType<typeof publication>): ScreenParticipantPublication {
  return { audio, identity, name: identity.toUpperCase(), video }
}

function descriptor(profile: string, generation: number, operation: number): string {
  return JSON.stringify({ ...descriptorFixture, requested_profile_id: profile, mode: profile.endsWith('_60') ? 'motion' : 'text',
    scope: { origin_id: 'https://app.example.test', account_id: '11111111-1111-4111-8111-111111111111', room_id: 'voice:channel-a', media_session_id: 'share-a', publication_generation: generation, operation_revision: operation } })
}

describe('LiveKit screen registry', () => {
  it('lists only remote screen-video publications and disables unselected screen tracks', () => {
    const aliceVideo = publication()
    const aliceAudio = publication()
    const bobVideo = publication()
    const registry = new LiveKitScreenRegistry()

    registry.refresh([participant('alice', aliceVideo, aliceAudio), participant('bob', bobVideo)], null)

    expect(registry.streams().map(({ hasAudio, id, participantId, participantName }) => ({ hasAudio, id, participantId, participantName }))).toEqual([
      { hasAudio: true, id: 'alice:screen', participantId: 'alice', participantName: 'ALICE' },
      { hasAudio: false, id: 'bob:screen', participantId: 'bob', participantName: 'BOB' },
    ])
    expect(aliceVideo.setSubscribed).toHaveBeenCalledWith(false)
    expect(aliceAudio.setSubscribed).toHaveBeenCalledWith(false)
    expect(bobVideo.setSubscribed).toHaveBeenCalledWith(false)
  })

  it('does not repeat unsubscribe after viewer clear and track-unsubscribed refreshes', async () => {
    const { ScreenViewerController } = await import('./screen_viewer_controller')
    function desiredPublication() {
      let desired = true
      return {
        get isDesired() { return desired },
        setSubscribed: vi.fn((value: boolean) => { desired = value }),
        track: { attach: vi.fn(), detach: vi.fn() },
      }
    }
    const video = desiredPublication(), audio = desiredPublication()
    const owner = { identity: 'screen-owner', video, audio }
    const registry = new LiveKitScreenRegistry()
    registry.refresh([owner], null)
    const viewer = new ScreenViewerController(() => registry.streams())
    viewer.select('screen-owner:screen', {} as HTMLVideoElement, {} as HTMLAudioElement)
    video.setSubscribed.mockClear(); audio.setSubscribed.mockClear()
    viewer.clear()
    // Both actual TrackUnsubscribed events trigger registry refresh separately.
    registry.refresh([owner], null)
    registry.refresh([owner], null)
    expect(video.setSubscribed).toHaveBeenCalledTimes(1)
    expect(audio.setSubscribed).toHaveBeenCalledTimes(1)
    expect(video.setSubscribed).toHaveBeenCalledWith(false)
    expect(audio.setSubscribed).toHaveBeenCalledWith(false)
  })

  it('does not turn off the currently selected stream while new room events arrive', () => {
    const video = publication()
    const audio = publication()
    const registry = new LiveKitScreenRegistry()

    registry.refresh([participant('alice', video, audio)], 'alice:screen')

    expect(video.setSubscribed).not.toHaveBeenCalled()
    expect(audio.setSubscribed).not.toHaveBeenCalled()
  })

  it('does not display a lease identity when a remote screen has no LiveKit name', () => {
    const registry = new LiveKitScreenRegistry()
    registry.refresh([{ identity: 'voice-lease:secret-lease', video: publication() }], null)
    expect(registry.streams()[0]?.participantName).toBe('Участник')
  })

  it('lists the owner screen as a silent self-preview without subscribing it', () => {
    const localVideo = { track: { attach: vi.fn(), detach: vi.fn() } }
    const registry = new LiveKitScreenRegistry()

    registry.refresh([{ accountId: 'self-account', identity: 'self-account', isLocal: true, name: 'Owner', video: localVideo }], null)

    expect(registry.streams()).toEqual([expect.objectContaining({
      accountId: 'self-account', hasAudio: false, id: 'local:self-account:screen', isLocal: true,
      participantId: 'self-account', participantName: 'Ваш экран', video: localVideo,
    })])
  })

  it('keeps legacy target labels for a track without a descriptor', () => {
    const registry = new LiveKitScreenRegistry()
    registry.refresh([participant('alice')], null)
    expect(registry.streams()[0]?.targetProfile).toBe('1080p · 30 FPS')
    expect(registry.streams()[0]?.profileSource).toBe('legacy-track-name')
  })

  it('uses the owner-checked latest descriptor instead of a stale track name', () => {
    const registry = new LiveKitScreenRegistry('https://app.example.test', 'voice:channel-a')
    const publicationWithMetadata: ScreenParticipantPublication = {
      ...participant('lease-a', { ...publication(), trackName: 'screenshare-1080p-30fps' }),
      accountId: '11111111-1111-4111-8111-111111111111',
      attributes: { 'boohtacord.screen-share.v1': descriptor('P720_60', 4, 12) },
    }
    registry.refresh([publicationWithMetadata], null)
    expect(registry.streams()[0]).toMatchObject({ targetProfile: '720p · 60 FPS', profileSource: 'sender-metadata' })
    publicationWithMetadata.attributes = { 'boohtacord.screen-share.v1': descriptor('P1080_60', 5, 13) }
    registry.refresh([publicationWithMetadata], null)
    publicationWithMetadata.attributes = { 'boohtacord.screen-share.v1': descriptor('P720_60', 4, 12) }
    registry.refresh([publicationWithMetadata], null)
    expect(registry.streams()[0]).toMatchObject({ targetProfile: '1080p · 60 FPS', profileSource: 'sender-metadata' })
  })

  it('retires a descriptor when a new publication SID arrives until its newer generation is observed', () => {
    const registry = new LiveKitScreenRegistry('https://app.example.test', 'voice:channel-a')
    const screen = participant('lease-a')
    const scoped = { ...screen, accountId: '11111111-1111-4111-8111-111111111111', attributes: { 'boohtacord.screen-share.v1': descriptor('P1080_60', 4, 12) } }
    scoped.video = { ...publication(), trackSid: 'old-sid' }
    registry.refresh([scoped], null)
    expect(registry.streams()[0]?.profileSource).toBe('sender-metadata')
    scoped.video = { ...publication(), trackSid: 'new-sid' }
    registry.refresh([scoped], null)
    expect(registry.streams()[0]).toMatchObject({ targetProfile: '1080p · 30 FPS', profileSource: 'legacy-track-name' })
    scoped.attributes = { 'boohtacord.screen-share.v1': descriptor('P720_60', 5, 13) }
    registry.refresh([scoped], null)
    expect(registry.streams()[0]).toMatchObject({ targetProfile: '720p · 60 FPS', profileSource: 'sender-metadata' })
  })

  it('ignores descriptors whose account, room, or origin does not match the publisher', () => {
    const registry = new LiveKitScreenRegistry('https://app.example.test', 'voice:channel-a')
    const invalid = JSON.parse(descriptor('P720_60', 4, 12))
    invalid.scope.account_id = '22222222-2222-4222-8222-222222222222'
    registry.refresh([{ ...participant('lease-a'), accountId: '11111111-1111-4111-8111-111111111111', attributes: { 'boohtacord.screen-share.v1': JSON.stringify(invalid) } }], null)
    expect(registry.streams()[0]).toMatchObject({ targetProfile: '1080p · 30 FPS', profileSource: 'legacy-track-name' })
  })
})
