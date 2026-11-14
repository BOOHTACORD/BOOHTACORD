import type { Ref } from 'vue'

import type { MicrophoneState } from './livekit_gateway'

export interface MicrophoneSession {
  setMicrophoneMuted(muted: boolean): Promise<MicrophoneState>
}

export function createMicrophoneControls(
  session: MicrophoneSession,
  active: Ref<{ microphoneAllowed?: boolean } | null>,
  state: Ref<string>,
  deafened: Ref<boolean>,
  microphoneMuted: Ref<boolean>,
  microphonePermissionDenied: Ref<boolean>,
  error: Ref<string | null>,
) {
  async function setMicrophoneMuted(muted: boolean): Promise<void> {
    if (!active.value || active.value.microphoneAllowed === false || deafened.value) return
    error.value = null
    try {
      const microphone = await session.setMicrophoneMuted(muted)
      microphoneMuted.value = microphone === 'MUTED'
      microphonePermissionDenied.value = microphone === 'LISTENER_PERMISSION_DENIED'
      if (microphone === 'PUBLISHED' && state.value === 'LISTENER') state.value = 'CONNECTED'
    } catch (cause) {
      error.value = cause instanceof Error ? cause.message : 'Не удалось изменить состояние микрофона.'
    }
  }

  async function toggleMicrophone(): Promise<void> {
    if (['JOINING', 'RECONNECTING', 'LEAVING'].includes(state.value)) return
    await setMicrophoneMuted(microphonePermissionDenied.value ? false : !microphoneMuted.value)
  }

  return { setMicrophoneMuted, toggleMicrophone }
}
