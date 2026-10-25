import { ref } from 'vue'

import { clearAuthenticatedState } from '../identity/clear_authenticated_state'
import { logout } from '../identity/logout_client'
import { useServerNotifications } from '../notification/server_preferences/state'

export interface LogoutPorts {
  stopMedia(): Promise<void>
  mediaActive(): boolean
  revoke(): Promise<void>
  disconnectRealtime(): void
  clearState(): void
  showGuest(): void
}

export function useWorkspaceLogout(ports: LogoutPorts) {
  const busy = ref(false)
  const error = ref<string | null>(null)

  async function signOut(): Promise<void> {
    if (busy.value) return
    busy.value = true
    error.value = null
    try {
      await ports.stopMedia()
      if (ports.mediaActive()) throw new Error('Не удалось остановить голосовое соединение. Повторите попытку.')
      await ports.revoke()
      ports.disconnectRealtime()
      ports.clearState()
      ports.showGuest()
    } catch (cause) {
      error.value = cause instanceof Error ? cause.message : 'Не удалось выйти из аккаунта. Повторите попытку.'
    } finally {
      busy.value = false
    }
  }

  return { busy, error, signOut }
}

export function bindWorkspaceLogout(
  voice: { active: unknown | null; stopScreen(): Promise<void> },
  leaveVoice: () => Promise<void>,
  realtime: { disconnect(): void },
  showGuest: () => void,
) {
  return useWorkspaceLogout({
    stopMedia: async () => { await voice.stopScreen(); await leaveVoice() },
    mediaActive: () => Boolean(voice.active),
    revoke: async () => { try { await logout() } finally { await useServerNotifications().clearDevice() } },
    disconnectRealtime: () => realtime.disconnect(),
    clearState: clearAuthenticatedState,
    showGuest,
  })
}
