import { afterEach, describe, expect, it, vi } from 'vitest'
import { LocalAudioTrack, LocalParticipant, LocalTrackPublication, LocalVideoTrack, Track } from 'livekit-client'
import { bindLiveKitScreenPublisher } from './screen_publisher/livekit_port'
import { screenPublisherEventHandlers } from './screen_publisher/events'
import { ScreenProfileGuard } from './screen_profile/guard'
import { adaptiveMediaRoomOptions } from './media_publishing'

afterEach(() => { vi.unstubAllEnvs(); vi.unstubAllGlobals() })

function setup(captureScreen?: () => Promise<unknown>) {
  const media = { readyState: 'live', contentHint: '', getSettings: () => ({ width: 2560, height: 1440, frameRate: 60 }), applyConstraints: vi.fn(async () => {}) }
  const video = { mediaStreamTrack: media, sender: { getParameters: () => ({ encodings: [] }), setParameters: vi.fn(), getStats: vi.fn() }, stop: vi.fn() } as unknown as LocalVideoTrack
  const audio = { stop: vi.fn() } as unknown as LocalAudioTrack, microphone = {} as LocalAudioTrack
  const publications = new Map<Track.Source, { videoTrack?: LocalVideoTrack; audioTrack?: LocalAudioTrack }>()
  let handlers: ReturnType<typeof screenPublisherEventHandlers<LocalVideoTrack, Track.Source.ScreenShare>>
  const unpublishTrack = vi.fn(async (track: LocalAudioTrack | LocalVideoTrack) => {
    const source = track === video ? Track.Source.ScreenShare : track === audio ? Track.Source.ScreenShareAudio : Track.Source.Microphone
    publications.delete(source)
    if (source === Track.Source.ScreenShare) handlers?.unpublished({ source, videoTrack: video })
  })
  const participant = {
    getTrackPublication: (source: Track.Source) => publications.get(source) as LocalTrackPublication | undefined,
    setScreenShareEnabled: vi.fn(async (enabled: boolean) => {
      if (!enabled) return undefined
      await captureScreen?.()
      publications.set(Track.Source.ScreenShare, { videoTrack: video }); publications.set(Track.Source.ScreenShareAudio, { audioTrack: audio })
      return { videoTrack: video } as LocalTrackPublication
    }),
    publishTrack: vi.fn(async (track: LocalVideoTrack) => {
      publications.set(Track.Source.ScreenShare, { videoTrack: track }); handlers?.published({ source: Track.Source.ScreenShare, videoTrack: track })
      return { videoTrack: track } as LocalTrackPublication
    }), unpublishTrack,
  } as unknown as LocalParticipant
  publications.set(Track.Source.Microphone, { audioTrack: microphone })
  const guard = new ScreenProfileGuard(() => video)
  const port = bindLiveKitScreenPublisher(participant, async () => ({ audioTrack: 'PRESENT', connectionQuality: 'UNKNOWN', measured: null, source: 'ACTIVE' }),
    profile => guard.adopt(profile), (profile, action, current) => guard.repair(profile, action, current))
  let guardStops = 0, ended = 0
  handlers = screenPublisherEventHandlers(port, Track.Source.ScreenShare, {
    suspend: () => guard.suspend(), resume: () => guard.resume(),
    stop: () => { guardStops++; guard.stop() },
  })
  port.onEnded?.(() => { ended++ })
  return { audio, video, microphone, port, participant, publications, handlers, guard, unpublishTrack, get guardStops() { return guardStops }, get ended() { return ended } }
}

describe('LiveKit screen publisher port', () => {
  it('prefers audio from the selected window for the browser capture', async () => {
    const getDisplayMedia = vi.fn(async () => ({} as MediaStream))
    const mediaDevices = { getDisplayMedia } as unknown as MediaDevices
    vi.stubGlobal('navigator', { mediaDevices })
    const f = setup(() => mediaDevices.getDisplayMedia({ audio: true, video: true }))

    await f.port.start('P1080_30')

    expect(getDisplayMedia).toHaveBeenCalledWith(expect.objectContaining({ audio: true, video: true, windowAudio: 'window' }))
    expect(mediaDevices.getDisplayMedia).toBe(getDisplayMedia)
  })

  it('uses managed video republish, keeping screen audio and microphone published', async () => {
    const f = setup(); await f.port.start('P1080_30'); f.port.adopt?.('P1080_30')
    await f.port.capture(f.video, 'P720_30'); await f.port.unpublish(f.video, false); await f.port.publish(f.video, 'P720_30')
    expect(f.publications.get(Track.Source.ScreenShareAudio)?.audioTrack).toBe(f.audio)
    expect(f.publications.get(Track.Source.Microphone)?.audioTrack).toBe(f.microphone)
    expect(f.participant.publishTrack).toHaveBeenCalledWith(f.video, expect.objectContaining({ source: Track.Source.ScreenShare, simulcast: false }))
    expect(f.guardStops).toBe(0)
    await f.port.stop(f.video)
    expect(f.publications.has(Track.Source.ScreenShareAudio)).toBe(false)
    expect(f.publications.get(Track.Source.Microphone)?.audioTrack).toBe(f.microphone)
  })
  it('preserves the optional bounded simulcast rollout through managed republish', async () => {
    vi.stubEnv('VITE_SCREEN_SHARE_BOUNDED_SIMULCAST', 'true')
    const f = setup(); await f.port.start('P1080_30'); f.port.adopt?.('P1080_30')
    await f.port.unpublish(f.video, false); await f.port.publish(f.video, 'P720_30')
    expect(f.participant.publishTrack).toHaveBeenCalledWith(f.video, expect.objectContaining({
      source: Track.Source.ScreenShare, simulcast: true, screenShareSimulcastLayers: expect.any(Array),
    }))
    expect(f.publications.get(Track.Source.ScreenShareAudio)?.audioTrack).toBe(f.audio)
    expect(f.publications.get(Track.Source.Microphone)?.audioTrack).toBe(f.microphone)
  })
  it('performs one explicit repair through managed-unpublish event hooks and rebinds the sender', async () => {
    const f = setup(); await f.port.start('P1080_30'); f.port.adopt?.('P1080_30')
    f.guard.snapshot = { status: 'drift', reason: 'configuration', attempts: 0 }
    const repaired = await f.port.repair?.(f.video, 'P1080_30', () => true)
    expect(repaired).toBe(true); expect(f.guard.snapshot).toMatchObject({ status: 'checking', attempts: 1 })
    expect(f.guardStops).toBe(0); expect(f.publications.get(Track.Source.ScreenShare)?.videoTrack).toBe(f.video)
    expect(f.publications.get(Track.Source.ScreenShareAudio)?.audioTrack).toBe(f.audio)
    expect(f.unpublishTrack).toHaveBeenCalledWith(f.video, false)
  })
  it('cleans surviving screen audio after an OS-ended video and leaves the microphone alone', async () => {
    const f = setup(); await f.port.start('P1080_30')
    ;(f.video.mediaStreamTrack as unknown as { readyState: string }).readyState = 'ended'
    f.publications.delete(Track.Source.ScreenShare)
    f.handlers.unpublished({ source: Track.Source.ScreenShare, videoTrack: f.video })
    await f.port.stop(f.video)
    expect(f.ended).toBe(1); expect(f.guardStops).toBe(1)
    expect(f.publications.has(Track.Source.ScreenShareAudio)).toBe(false)
    expect(f.publications.get(Track.Source.Microphone)?.audioTrack).toBe(f.microphone)
    expect(f.unpublishTrack).not.toHaveBeenCalledWith(f.video, true)
  })
  it('does not treat a still-live retained capture as an OS end during SDK republish', async () => {
    const f = setup(); await f.port.start('P1080_30')
    f.guard.adopt('P1080_30'); f.handlers.reconnecting()
    f.publications.delete(Track.Source.ScreenShare)
    f.handlers.unpublished({ source: Track.Source.ScreenShare, videoTrack: f.video })
    await f.guard.check()
    expect(f.video.mediaStreamTrack.readyState).toBe('live')
    expect(f.ended).toBe(0); expect(f.guardStops).toBe(0)
    f.publications.set(Track.Source.ScreenShare, { videoTrack: f.video })
    f.handlers.published({ source: Track.Source.ScreenShare, videoTrack: f.video })
    f.handlers.reconnected()
    expect(f.guard.snapshot).toMatchObject({ status: 'checking', attempts: 0 })
    expect(f.port.currentTrack()).toBe(f.video)
  })
  it('keeps adaptive room receive settings enabled', () => { expect(adaptiveMediaRoomOptions).toEqual({ adaptiveStream: true, dynacast: true }) })
})
