import { TrackInfo, TrackSource, TrackType } from '@livekit/protocol'
import { RemoteTrackPublication, Track, TrackEvent } from 'livekit-client'
import { describe, expect, it, vi } from 'vitest'
import { LiveKitScreenRegistry } from './livekit_screen_registry'
import type { ScreenViewerPublication } from './screen_viewer_types'
import { screenTargetSourceLabel } from './screen_profile_metadata/presentation'
import { bindLiveKitScreenViewer, type LiveKitScreenViewerRoom } from './livekit_screen_viewer_adapter'
import { readFileSync } from 'node:fs'

function publication(trackName: string, sid = 'TR_qa') {
  return new RemoteTrackPublication(Track.Kind.Video, new TrackInfo({ sid, name: trackName, type: TrackType.VIDEO, source: TrackSource.SCREEN_SHARE }), false)
}

// Compile-time SDK boundary; preserve actual prototype methods and getters.
const sdkPublication: ScreenViewerPublication = publication('screenshare-1080p-60fps')

describe('pinned LiveKit SDK screen publication boundary', () => {
  it('labels a legacy target as a launch profile, without claiming current encoder settings', () => {
    expect(screenTargetSourceLabel('legacy-track-name')).toContain('Профиль при запуске')
  })
  for (const height of [720, 1080, 1440]) for (const fps of [15, 30, 60]) {
    it(`reads native legacy ${height}p${fps} from a real SDK publication without name`, () => {
      const video = publication(`screenshare-${height}p-${fps}fps`)
      expect('name' in video).toBe(false)
      expect(video.trackName).toBe(`screenshare-${height}p-${fps}fps`)
      const registry = new LiveKitScreenRegistry()
      registry.refresh([{ identity: 'synthetic-peer', name: 'Synthetic person', video }], null)
      expect(registry.streams()[0]).toMatchObject({ participantName: 'Synthetic person', targetProfile: `${height}p · ${fps} FPS`, profileSource: 'legacy-track-name', video })
      expect(registry.streams()[0]!.video).toBe(video)
    })
  }
  for (const name of ['', 'screenshare-1080p-59fps', 'screenshare-2160p-60fps', 'unknown']) {
    it(`keeps unknown SDK track profile unknown: ${name || 'empty'}`, () => {
      const registry = new LiveKitScreenRegistry()
      registry.refresh([{ identity: 'synthetic-peer', video: publication(name) }], null)
      expect(registry.streams()[0]).toMatchObject({ profileSource: 'unknown', targetProfile: undefined })
    })
  }
  it('keeps real subscription methods/getters and silent local preview intact', () => {
    const video = publication('screenshare-1080p-60fps')
    const updates = vi.fn()
    video.on(TrackEvent.UpdateSubscription, updates)
    const registry = new LiveKitScreenRegistry()
    registry.refresh([{ identity: 'synthetic-peer', video }], null)
    expect(video.isDesired).toBe(false)
    expect(updates).not.toHaveBeenCalled()
    video.setSubscribed(true)
    registry.refresh([{ identity: 'synthetic-peer', video }], 'synthetic-peer:screen')
    expect(video.isDesired).toBe(true)
    expect(updates).toHaveBeenCalledTimes(1)
    registry.refresh([{ identity: 'synthetic-peer', video }], null)
    registry.refresh([{ identity: 'synthetic-peer', video }], null)
    expect(video.isDesired).toBe(false)
    expect(updates).toHaveBeenCalledTimes(2)
    registry.refresh([{ identity: 'local-peer', isLocal: true, video: sdkPublication }], null)
    expect(registry.streams()[0]).toMatchObject({ participantName: 'Ваш экран', hasAudio: false, profileSource: 'legacy-track-name' })
    registry.refresh([], null)
    expect(registry.streams()).toEqual([])
  })
  it('passes the real SDK publication through the adapter for late join, reconnect and SID replacement', () => {
    const listeners = new Map<unknown, Array<(...args: unknown[]) => void>>()
    let video: RemoteTrackPublication | undefined = publication('screenshare-1080p-60fps')
    const participant = { identity: 'synthetic-peer', name: 'Synthetic person', getTrackPublication: (source: unknown) => source === 'screen-video' ? video : undefined }
    const room: LiveKitScreenViewerRoom = { remoteParticipants: new Map([['synthetic-peer', participant]]), on: (event, listener) => { listeners.set(event, [...listeners.get(event) ?? [], listener]) } }
    const events = { activeSpeakersChanged: 'speakers', localTrackPublished: 'local-published', localTrackUnpublished: 'local-unpublished', participantConnected: 'connected', participantDisconnected: 'disconnected', trackMuted: 'muted', trackPublished: 'published', trackSubscribed: 'subscribed', trackUnmuted: 'unmuted', trackUnpublished: 'unpublished', trackUnsubscribed: 'unsubscribed' }
    const binding = bindLiveKitScreenViewer(room, events, { microphone: 'mic', screenAudio: 'screen-audio', screenVideo: 'screen-video' })
    binding.refresh()
    expect(binding.viewer.cards()[0]).toMatchObject({ targetProfile: '1080p · 60 FPS', profileSource: 'legacy-track-name', participantName: 'Synthetic person' })
    video = publication('screenshare-720p-15fps', 'TR_replaced')
    listeners.get('published')!.forEach(listener => listener(video, participant))
    expect(binding.viewer.cards()[0]).toMatchObject({ targetProfile: '720p · 15 FPS', profileSource: 'legacy-track-name' })
    binding.clear()
    binding.refresh()
    expect(binding.viewer.cards()[0]?.targetProfile).toBe('720p · 15 FPS')
    video = undefined
    listeners.get('unpublished')!.forEach(listener => listener({ source: 'screen-video' }, participant))
    expect(binding.viewer.cards()).toEqual([])
  })
  it('keeps owner and generation descriptor guards above the real SDK legacy name', () => {
    const fixture = JSON.parse(readFileSync(new URL('../../../../contracts/screen-share-profile-v1.fixtures.json', import.meta.url), 'utf8')).validDescriptor
    const accountId = '11111111-1111-4111-8111-111111111111'
    const raw = (profile: string, generation: number, operation: number, owner = accountId) => JSON.stringify({ ...fixture, requested_profile_id: profile, mode: profile.endsWith('_60') ? 'motion' : 'text', scope: { ...fixture.scope, origin_id: 'https://app.example.test', room_id: 'voice:qa', account_id: owner, media_session_id: 'synthetic-session', publication_generation: generation, operation_revision: operation } })
    const registry = new LiveKitScreenRegistry('https://app.example.test', 'voice:qa', true)
    const peer = { identity: 'synthetic-peer', accountId, video: publication('screenshare-1080p-60fps'), attributes: { 'boohtacord.screen-share.v1': raw('P720_30', 1, 2) } }
    registry.refresh([peer], null)
    expect(registry.streams()[0]).toMatchObject({ targetProfile: '720p · 30 FPS', profileSource: 'sender-metadata' })
    peer.attributes['boohtacord.screen-share.v1'] = raw('P1440_60', 1, 1)
    registry.refresh([peer], null)
    expect(registry.streams()[0]?.targetProfile).toBe('720p · 30 FPS')
    peer.attributes['boohtacord.screen-share.v1'] = raw('P1440_60', 1, 3, '22222222-2222-4222-8222-222222222222')
    registry.refresh([peer], null)
    expect(registry.streams()[0]).toMatchObject({ targetProfile: '1080p · 60 FPS', profileSource: 'legacy-track-name' })
    peer.attributes['boohtacord.screen-share.v1'] = raw('P720_30', 1, 2)
    registry.refresh([peer], null)
    peer.video = publication('screenshare-1440p-15fps', 'TR_new')
    registry.refresh([peer], null)
    expect(registry.streams()[0]).toMatchObject({ targetProfile: '1440p · 15 FPS', profileSource: 'legacy-track-name' })
    peer.attributes['boohtacord.screen-share.v1'] = raw('P1080_30', 2, 3)
    registry.refresh([peer], null)
    expect(registry.streams()[0]).toMatchObject({ targetProfile: '1080p · 30 FPS', profileSource: 'sender-metadata' })
  })
})
