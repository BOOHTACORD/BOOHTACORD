import type { LocalVideoTrack, Room, Track } from 'livekit-client'
import { updateScreenProfileDescriptor } from './client'
import { SCREEN_DESCRIPTOR_ATTRIBUTE } from './descriptor'
import { screenDescriptorMetadataEnabled } from './enabled'
import { ScreenProfileMetadataPublisher } from './publisher'
import type { ScreenProfile } from '../screen_profile/policy'
import type { ScreenProfileMode } from './types'

export function bindLiveKitScreenMetadata(room: Room, screenSource: Track.Source, generation: () => number) {
  if (!screenDescriptorMetadataEnabled()) {
    return { bindLease: async () => undefined, publish: async () => undefined, clear: async () => undefined, reconnected: () => undefined }
  }
  let leaseId = ''
  let activeProfile: ScreenProfile | undefined
  let activeMode: ScreenProfileMode = 'motion'
  let publisher: ScreenProfileMetadataPublisher | undefined
  const videoTrack = () => room.localParticipant.getTrackPublication(screenSource)?.videoTrack as (LocalVideoTrack & { sender?: RTCRtpSender }) | undefined

  async function bindLease(value: string): Promise<void> {
    if (publisher && leaseId === value) return
    await publisher?.clear().catch(() => undefined)
    activeProfile = undefined
    leaseId = value
    publisher = new ScreenProfileMetadataPublisher({
      setAttributes: async attributes => {
        const descriptor = attributes[SCREEN_DESCRIPTOR_ATTRIBUTE]
        if (!leaseId || !descriptor) throw new Error('Нет активной серверной lease демонстрации.')
        await updateScreenProfileDescriptor(leaseId, JSON.parse(descriptor))
      },
    }, { originId: window.location.origin, accountId: '', roomId: room.name })
  }

  async function publish(profile: ScreenProfile, mode: ScreenProfileMode = activeMode): Promise<void> {
    const track = videoTrack(), settings = track?.mediaStreamTrack.getSettings()
    if (!track || !settings?.width || !settings.height || !publisher) return
    const actualEncodings = track.sender?.getParameters().encodings
    if (!actualEncodings?.length) return
    const encodings = actualEncodings.map(encoding => ({
      rid: encoding.rid, active: encoding.active, maxBitrate: encoding.maxBitrate,
      maxFramerate: encoding.maxFramerate, scaleResolutionDownBy: encoding.scaleResolutionDownBy,
    })) ?? []
    activeProfile = profile
    activeMode = mode
    await publisher.publish(profile, Math.max(1, generation()), { width: settings.width, height: settings.height }, encodings, mode)
  }

  async function clear(): Promise<void> {
    activeProfile = undefined
    await publisher?.clear()
  }

  function reconnected(): void {
    if (activeProfile) void publish(activeProfile, activeMode).catch(() => undefined)
  }

  return { bindLease, publish, clear, reconnected }
}
