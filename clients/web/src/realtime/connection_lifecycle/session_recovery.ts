import { loadCurrentSession } from '../../identity/current_session'
import { boundedSessionCheck } from '../socket_attempt'
import type { RealtimeConnectOptions } from '../realtime_connection_types'

export function createSessionRecovery(check: RealtimeConnectOptions['checkSession'], expired: () => void, schedule: () => void) {
  let cancelPending = () => {}
  return {
    cancel(): void { cancelPending() },
    async check(isCurrent: () => boolean): Promise<void> {
      let valid: boolean | null = null
      const pending = boundedSessionCheck(check ?? (async signal => (await loadCurrentSession(undefined, signal)) !== null))
      cancelPending = pending.cancel
      try { valid = await pending.result }
      catch { /* A network failure does not prove session revocation. */ }
      finally { if (cancelPending === pending.cancel) cancelPending = () => {} }
      if (!isCurrent()) return
      if (valid === false) { expired(); return }
      schedule()
    },
  }
}
