import { describe, expect, it, vi } from 'vitest'
import { Track, type LocalVideoTrack, type Room } from 'livekit-client'
import { updateScreenProfileDescriptor } from './client'
import { bindLiveKitScreenMetadata } from './livekit_binding'
import type { ScreenShareDescriptorV1 } from './types'

vi.mock('./client', () => ({ updateScreenProfileDescriptor: vi.fn(async () => undefined) }))

describe('LiveKit screen metadata lease binding', () => {
  it('preserves revision for the same lease and idles old metadata before switching leases', async () => {
    const update = vi.mocked(updateScreenProfileDescriptor)
    update.mockClear()
    const videoTrack = {
      mediaStreamTrack: { getSettings: () => ({ width: 1920, height: 1080 }) },
      sender: { getParameters: () => ({ encodings: [{ maxBitrate: 5_000_000, maxFramerate: 30 }] }) },
    } as unknown as LocalVideoTrack & { sender?: RTCRtpSender }
    const room = {
      name: 'voice:channel',
      localParticipant: { getTrackPublication: () => ({ videoTrack }) },
    } as unknown as Room
    const metadata = bindLiveKitScreenMetadata(room, Track.Source.ScreenShare, () => 2)
    vi.stubGlobal('window', { location: { origin: 'https://app.example.test' } })

    try {
      await metadata.bindLease('lease-a')
      expect(metadata.readTelemetryScope()).toBeUndefined()
      await metadata.publish('P1080_30')
      expect(metadata.readTelemetryScope()).toEqual({
        ownerLeaseId: 'lease-a', mediaSessionId: expect.any(String), publicationGeneration: 2,
        captureWidth: 1920, captureHeight: 1080, captureFps: 30,
      })
      await metadata.bindLease('lease-a')
      await metadata.publish('P720_30')
      expect(metadata.readTelemetryScope()).toMatchObject({ ownerLeaseId: 'lease-a', captureWidth: 1920, captureHeight: 1080, captureFps: 30 })
      await metadata.bindLease('lease-b')
      expect(metadata.readTelemetryScope()).toBeUndefined()
      await metadata.publish('P1080_30')

      const descriptor = (index: number) => update.mock.calls[index]?.[1] as ScreenShareDescriptorV1
      expect(update.mock.calls.map(call => call[0])).toEqual(['lease-a', 'lease-a', 'lease-a', 'lease-b'])
      expect(descriptor(0).scope.operation_revision).toBe(1)
      expect(descriptor(1).scope.operation_revision).toBe(2)
      expect(descriptor(2)).toMatchObject({ publisher_state: 'idle', scope: { operation_revision: 3 } })
      expect(descriptor(3).scope.operation_revision).toBe(1)
    } finally { vi.unstubAllGlobals() }
  })
})
