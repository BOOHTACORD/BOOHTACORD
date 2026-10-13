import {LogLevel, Room, setLogLevel, type LocalVideoTrack} from 'livekit-client'
import {createSyntheticCapture} from './baseline/capture'
import {publishBaselineCapture} from './baseline/publish'
import {sampleSender} from './baseline/stats'
import {SCREEN_DESCRIPTOR_ATTRIBUTE} from '../../src/voice/screen_profile_metadata/descriptor'
import {ScreenProfileMetadataPublisher} from '../../src/voice/screen_profile_metadata/publisher'
import {updateScreenProfileDescriptor} from '../../src/voice/screen_profile_metadata/client'
import type {ScreenDescriptorOwner, ScreenProfileMode} from '../../src/voice/screen_profile_metadata/types'

let room: Room | undefined, track: LocalVideoTrack | undefined
let capture: ReturnType<typeof createSyntheticCapture> | undefined
let publisher: ScreenProfileMetadataPublisher | undefined
let generatedFrames = 0

async function metadata(mode: ScreenProfileMode) {
  const settings = track?.mediaStreamTrack.getSettings()
  const encodings = track?.sender?.getParameters().encodings
  if (!publisher || !settings?.width || !settings.height || !encodings?.length) throw new Error('Fresh Web sender configuration unavailable')
  const limits = encodings.map(encoding => ({rid: encoding.rid, active: encoding.active, maxBitrate: encoding.maxBitrate, maxFramerate: encoding.maxFramerate, scaleResolutionDownBy: encoding.scaleResolutionDownBy}))
  await publisher.publish('P1080_60', 1, {width: settings.width, height: settings.height}, limits, mode)
  return {source: 'synthetic-canvas', mode, profile: 'P1080_60', capture_configuration: {width: settings.width, height: settings.height, frameRate: settings.frameRate ?? null}, fresh_encoder_limits: limits.map(value => ({max_fps: value.maxFramerate, max_bitrate_bps: value.maxBitrate, scale_down_by: value.scaleResolutionDownBy ?? 1, active: value.active ?? true})), generatedFrames}
}
async function stop() {
  await publisher?.clear().catch(() => undefined)
  publisher = undefined
  capture?.stop()
  if (track && room) await room.localParticipant.unpublishTrack(track, true).catch(() => undefined)
  track?.stop()
  capture?.stream.getTracks().forEach(value => value.stop())
  track = undefined
  capture = undefined
  await room?.disconnect(true)
  room = undefined
}

;(window as any).descriptorSender = {
  async start(input: {url: string; token: string; lease: string; owner: ScreenDescriptorOwner}) {
    setLogLevel(LogLevel.silent)
    room = new Room({adaptiveStream: false, dynacast: false})
    await room.connect(input.url, input.token)
    capture = createSyntheticCapture(frame => {generatedFrames = frame}, 60)
    track = await publishBaselineCapture(room, capture.stream, () => {void stop()})
    publisher = new ScreenProfileMetadataPublisher({setAttributes: async attributes => {
      const raw = attributes[SCREEN_DESCRIPTOR_ATTRIBUTE]
      if (!raw) throw new Error('Descriptor required')
      // Real secure-cookie API is reached by the owned Node context. Vite's
      // separate origin cannot supply its cookie; production serialization and
      // retry code remain in use, without giving the SDK metadata privileges.
      await updateScreenProfileDescriptor(input.lease, JSON.parse(raw), async (path, init) => {
        const expected = '/api/v1/voice/leases/' + encodeURIComponent(input.lease) + '/screen-profile/v1'
        if (new URL(path, window.location.origin).pathname !== expected || init.method !== 'PUT' || typeof init.body !== 'string') throw new Error('Protected descriptor request required')
        const status = await (window as any).qaProtectedDescriptorWrite(JSON.parse(init.body))
        return new Response(null, {status})
      })
    }}, input.owner)
    return metadata('motion')
  },
  metadata,
  sample: async () => ({generatedFrames, outbound: await sampleSender(track ?? null)}),
  stop,
}
