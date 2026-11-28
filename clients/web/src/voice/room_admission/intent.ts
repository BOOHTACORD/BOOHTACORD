import type { LiveKitCredential } from '../admission_client'

export interface VoiceRoomJoinOptions {
  current?: () => boolean
  refreshCredential?: () => Promise<LiveKitCredential>
}

export function assertJoinIntent(options: VoiceRoomJoinOptions): void {
  if (options.current?.() === false) throw new Error('Голосовое подключение отменено.')
}
