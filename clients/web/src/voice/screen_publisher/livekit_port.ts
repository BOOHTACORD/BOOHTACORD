import { Track, type LocalParticipant, type LocalVideoTrack } from 'livekit-client'
import { applyScreenProfile } from '../screen_profile/apply'
import type { ScreenDiagnostics } from '../screen_diagnostics'
import { screenCapturePlan, screenPublishPlan } from './plan'
import type { ScreenProfile } from '../screen_profile/policy'
import type { ScreenPublisherPort } from './types'
import { screenMediaRollout } from '../screen_rollout/policy'
import { withWindowAudioPreference } from './window_audio_capture'

export function bindLiveKitScreenPublisher(participant: LocalParticipant, diagnostics: () => Promise<ScreenDiagnostics>, adopt: (profile: ScreenProfile) => void, repair: (profile: ScreenProfile, action: () => Promise<void>, current: () => boolean) => Promise<boolean>) {
  const rollout = screenMediaRollout()
  const publicationPlan = (profile: ScreenProfile) => screenPublishPlan(profile, undefined, rollout.boundedSimulcast, rollout.codecPolicy)
  let generation = 0
  const expectedUnpublish = new WeakSet<LocalVideoTrack>(), ended = new Set<() => void>()
  const published = new Set<(track: LocalVideoTrack) => void>()
  const currentTrack = () => participant.getTrackPublication(Track.Source.ScreenShare)?.videoTrack
  async function unpublish(track: LocalVideoTrack, stopCapture: boolean): Promise<void> {
    expectedUnpublish.add(track)
    try { await participant.unpublishTrack(track, stopCapture) }
    catch (cause) { expectedUnpublish.delete(track); throw cause }
    expectedUnpublish.delete(track)
  }
  const port: ScreenPublisherPort<LocalVideoTrack> = {
    generation: () => generation,
    isLive: track => track.mediaStreamTrack.readyState === 'live',
    currentTrack,
    start: async profile => withWindowAudioPreference(async () =>
      (await participant.setScreenShareEnabled(true, screenCapturePlan(profile), publicationPlan(profile)))?.videoTrack ?? currentTrack()),
    capture: (track, profile) => applyScreenProfile(track, profile),
    unpublish,
    publish: async (track, profile) => { await participant.publishTrack(track, { ...publicationPlan(profile), source: Track.Source.ScreenShare }) },
    stop: async track => {
      let failure: unknown
      const published = currentTrack(), staleTrack = Boolean(track && published && published !== track)
      const video = track ? (published === track ? track : undefined) : published
      try {
        if (video) await unpublish(video, true)
        else if (track && track.mediaStreamTrack.readyState === 'live') track.stop()
      } catch (cause) { failure = cause }
      const audio = staleTrack ? undefined : participant.getTrackPublication(Track.Source.ScreenShareAudio)?.audioTrack
      try { if (audio) await participant.unpublishTrack(audio, true) } catch (cause) { failure ??= cause }
      if (!video && !audio && !track) void participant.setScreenShareEnabled(false).catch(() => {})
      if (failure) throw failure
    },
    diagnostics,
    adopt,
    repair: (track, profile, current) => repair(profile, async () => {
      if (!current()) throw new Error('Операция восстановления отменена.')
      await applyScreenProfile(track, profile)
      await unpublish(track, false)
      if (!current()) throw new Error('Операция восстановления отменена.')
      await participant.publishTrack(track, { ...publicationPlan(profile), source: Track.Source.ScreenShare })
      if (currentTrack() !== track) throw new Error('LiveKit не подтвердил восстановленную публикацию.')
    }, current),
    onEnded: listener => { ended.add(listener); return () => ended.delete(listener) },
    onPublished: listener => { published.add(listener); return () => published.delete(listener) },
    trackPublished: track => { ++generation; published.forEach(listener => listener(track)) },
    trackUnpublished: track => {
      ++generation
      if (track && expectedUnpublish.delete(track)) return true
      if (track?.mediaStreamTrack.readyState === 'live') return true
      for (const listener of ended) listener()
      return false
    },
  }
  return port
}
