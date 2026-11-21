import type { LiveKitCredential } from '../admission_client'
import type { JoinedVoiceRoom, VoiceJoinMode, VoiceRoomFactory } from '../livekit_gateway'
import { setMicrophone, type AudioProcessingOptions } from '../media_publishing'
import { awaitMediaConnection, mediaConnectionTimeoutMs } from '../connection_deadline'
import { defaultLiveKitRoomFactory } from '../livekit_room_factory'
import { activeAction } from '../../telemetry/action_scope/scope'
import { disconnectFailedRoom } from './disconnect'

export async function connectLiveKitRoom(
  credential: LiveKitCredential,
  makeRoom: VoiceRoomFactory = defaultLiveKitRoomFactory,
  processing?: AudioProcessingOptions,
  timeoutMs = mediaConnectionTimeoutMs,
  joinMode: VoiceJoinMode = 'with-microphone',
  inputDeviceId?: string,
): Promise<JoinedVoiceRoom> {
  const room = await makeRoom()
  try {
    await awaitMediaConnection(room.connect(credential.url, credential.token, { autoSubscribe: false }), timeoutMs)
    if (inputDeviceId !== undefined) await awaitMediaConnection(room.switchActiveDevice('audioinput', inputDeviceId), timeoutMs)
  } catch (cause) {
    await disconnectFailedRoom(room)
    throw cause
  }

  if (joinMode === 'listener' || credential.microphoneAllowed === false) return { room, microphone: 'MUTED' }

  try {
    activeAction()?.step('microphone')
    return { room, microphone: await awaitMediaConnection(setMicrophone(room, true, processing), timeoutMs) }
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
): Promise<JoinedVoiceRoom> {
  return connectLiveKitRoom(credential, defaultLiveKitRoomFactory, processing, undefined, joinMode, inputDeviceId)
}
