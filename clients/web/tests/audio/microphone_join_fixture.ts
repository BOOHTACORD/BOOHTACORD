import { LocalAudioTrack, Room, RoomEvent } from 'livekit-client'
import { connectLiveKitRoom, type VoiceRoom } from '../../src/voice/livekit_gateway'
import { defaultLiveKitRoomFactory } from '../../src/voice/livekit_room_factory'
import type { NoiseSuppressionMode } from '../../src/voice/noise_suppression/types'

let room: VoiceRoom | undefined
let track: LocalAudioTrack | undefined

const gate = {
  async join(mode: NoiseSuppressionMode, interruptPublication: boolean) {
    const credential = await (await fetch('/tests/audio/livekit-token?role=sender', { cache: 'no-store' })).json()
    const voiceRoom = await defaultLiveKitRoomFactory()
    room = voiceRoom
    const sdk = voiceRoom as unknown as Room
    // Chromium's fake capture device supplies synthetic audio. Use the actual
    // production capture/processor/publication path and retain its cleanup probe.
    let attempts = 0, cancellations = 0, reconnects = 0
    const enabledAtPublish: boolean[] = []
    sdk.on(RoomEvent.Reconnecting, () => reconnects++)
    const publish = sdk.localParticipant.publishTrack.bind(sdk.localParticipant)
    sdk.localParticipant.publishTrack = async (local, options) => {
      if (local instanceof LocalAudioTrack) track = local
      enabledAtPublish.push((local instanceof MediaStreamTrack ? local : local.mediaStreamTrack).enabled)
      try { return await publish(local, options) }
      catch (cause) {
        if (cause instanceof Error && cause.message === 'Cancelled publication by calling unpublish') cancellations++
        throw cause
      }
    }
    const sendAddTrack = sdk.engine.client.sendAddTrack.bind(sdk.engine.client)
    sdk.engine.client.sendAddTrack = async (request) => {
      attempts++
      if (interruptPublication && attempts === 1) {
        // Leave the real addTrack request pending, then force the SDK's full
        // signaling restart. cleanupClient emits the reported cancellation.
        void sdk.simulateScenario('resume-reconnect')
        return
      }
      await sendAddTrack(request)
    }
    const joined = await connectLiveKitRoom(credential, () => voiceRoom, {
      autoGainControl: false, echoCancellation: false, noiseSuppressionMode: mode,
    })
    return {
      microphone: joined.microphone, attempts, cancellations, reconnects, enabledAtPublish,
      publications: sdk.localParticipant.audioTrackPublications.size,
      processingState: voiceRoom.readNoiseSuppressionState?.(),
    }
  },
  async switchMode(mode: NoiseSuppressionMode) {
    const publications = (room as unknown as Room).localParticipant.audioTrackPublications
    const previous = [...publications.keys()][0]
    await room!.applyMicrophoneProcessing!({ autoGainControl: false, echoCancellation: false, noiseSuppressionMode: mode })
    return { processing: room!.readNoiseSuppressionState!(),
      replaced: previous !== [...publications.keys()][0], publications: publications.size }
  },
  async mute() { await room?.setMicrophone?.(false, { autoGainControl: false, echoCancellation: false, noiseSuppressionMode: 'off' }) },
  async stop() {
    try { await room?.disconnect() }
    finally { room = undefined }
    const ended = track?.mediaStreamTrack.readyState === 'ended'
    track = undefined
    return { ended }
  },
}
;(window as unknown as { microphoneJoinGate: typeof gate }).microphoneJoinGate = gate
