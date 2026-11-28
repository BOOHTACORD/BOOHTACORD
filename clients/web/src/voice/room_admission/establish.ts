import { ConnectionError, ConnectionErrorReason } from 'livekit-client'
import type { LiveKitCredential } from '../admission_client'
import type { VoiceRoom, VoiceRoomFactory } from '../livekit_gateway'
import { awaitMediaConnection } from '../connection_deadline'
import { disconnectFailedRoom } from './disconnect'
import { assertJoinIntent, type VoiceRoomJoinOptions } from './intent'

const signalRetryDelayMs = 2000
function transientSignalFailure(cause: unknown): boolean {
  return cause instanceof ConnectionError && cause.reason === ConnectionErrorReason.WebSocket &&
    !(cause.status !== undefined && cause.status >= 400 && cause.status < 500)
}

// An early failed WS upgrade has no active session for the reconnect monitor.
// Retain the exact lease, recheck its credential/ACL and replace the failed room
// once, inside the original connection deadline. Never retry capture or admission.
export async function establishVoiceRoom(
  initialCredential: LiveKitCredential, factory: VoiceRoomFactory, timeoutMs: number,
  options: VoiceRoomJoinOptions,
): Promise<{ room: VoiceRoom; credential: LiveKitCredential }> {
  const deadline = performance.now() + timeoutMs
  const remaining = () => Math.max(0, deadline - performance.now())
  let credential = initialCredential
  for (let attempt = 0; ; attempt++) {
    assertJoinIntent(options)
    if (attempt && !remaining()) throw new Error('Превышено время ожидания голосового подключения.')
    const room = await factory()
    try {
      assertJoinIntent(options)
      if (!remaining()) throw new Error('Превышено время ожидания голосового подключения.')
      await awaitMediaConnection(room.connect(credential.url, credential.token, { autoSubscribe: false }), remaining())
      assertJoinIntent(options)
      return { room, credential }
    } catch (cause) {
      await disconnectFailedRoom(room)
      assertJoinIntent(options)
      if (attempt !== 0 || !transientSignalFailure(cause) || remaining() <= signalRetryDelayMs) throw cause
      await new Promise(resolve => setTimeout(resolve, signalRetryDelayMs))
      assertJoinIntent(options)
      const timeout = remaining()
      if (!timeout) throw new Error('Превышено время ожидания голосового подключения.')
      if (options.refreshCredential) credential = await awaitMediaConnection(options.refreshCredential(), timeout)
      assertJoinIntent(options)
    }
  }
}
