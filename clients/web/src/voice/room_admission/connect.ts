import type { LiveKitCredential } from '../admission_client'
import type { JoinedVoiceRoom, VoiceJoinMode, VoiceRoomFactory } from '../livekit_gateway'
import { setMicrophone, type AudioProcessingOptions } from '../media_publishing'
import { awaitMediaConnection, mediaConnectionTimeoutMs } from '../connection_deadline'
import { defaultLiveKitRoomFactory } from '../livekit_room_factory'
import { activeAction } from '../../telemetry/action_scope/scope'
import { disconnectFailedRoom } from './disconnect'
import { establishVoiceRoom } from './establish'
import { assertJoinIntent, type VoiceRoomJoinOptions } from './intent'

export async function connectLiveKitRoom(
  credential: LiveKitCredential,
  makeRoom: VoiceRoomFactory = defaultLiveKitRoomFactory,
  processing?: AudioProcessingOptions,
  timeoutMs = mediaConnectionTimeoutMs,
  joinMode: VoiceJoinMode = 'with-microphone',
  inputDeviceId?: string,
  options: VoiceRoomJoinOptions = {},
): Promise<JoinedVoiceRoom> {
  const { room, credential: connectedCredential } = await establishVoiceRoom(credential, makeRoom, timeoutMs, options)
  try {
    if (inputDeviceId !== undefined) await awaitMediaConnection(room.switchActiveDevice('audioinput', inputDeviceId), timeoutMs)
    assertJoinIntent(options)
    if (joinMode === 'listener' || connectedCredential.microphoneAllowed === false) return { room, microphone: 'MUTED' }

    activeAction()?.step('microphone')
    const microphone = await awaitMediaConnection(setMicrophone(room, true, processing), timeoutMs)
    assertJoinIntent(options)
    return { room, microphone }
  } catch (cause) {
    await disconnectFailedRoom(room)
    throw cause
  }
}

export async function connectLiveKitRoomWithProcessing(
  credential: LiveKitCredential,
  processing?: AudioProcessingOptions,
  joinMode: VoiceJoinMode = 'with-microphone',
  inputDeviceId?: string,
  options?: VoiceRoomJoinOptions,
): Promise<JoinedVoiceRoom> {
  return connectLiveKitRoom(credential, defaultLiveKitRoomFactory, processing, undefined, joinMode, inputDeviceId, options)
}
