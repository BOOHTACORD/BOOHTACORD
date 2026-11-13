import type { RealtimeSocket } from './realtime_connection_types'

export const HEARTBEAT_PROTOCOL = 'boohtacord.heartbeat.v1'
const SILENCE_LIMIT_MS = 45_000

export function createLivenessWatch(socket: RealtimeSocket, onTimeout: () => void) {
  let ready = false, listening = false, lastSeen = 0, timer: ReturnType<typeof setTimeout> | null = null
  const visible = () => { if (ready && document.visibilityState === 'visible' && Date.now() - lastSeen >= SILENCE_LIMIT_MS) onTimeout() }
  const online = () => { if (ready) onTimeout() }
  function stop(): void {
    if (timer !== null) clearTimeout(timer)
    timer = null; ready = false
    if (listening) {
      if (typeof document !== 'undefined') document.removeEventListener('visibilitychange', visible)
      if (typeof window !== 'undefined') window.removeEventListener('online', online)
      listening = false
    }
  }
  return {
    observe(kind: string): boolean {
      if (socket.protocol !== HEARTBEAT_PROTOCOL) return kind !== 'connection.heartbeat'
      if (kind === 'connection.heartbeat' && !ready) return false
      if (kind === 'connection.ready') ready = true
      if (!ready) return true
      if (!listening) {
        if (typeof document !== 'undefined') document.addEventListener('visibilitychange', visible)
        if (typeof window !== 'undefined') window.addEventListener('online', online)
        listening = true
      }
      lastSeen = Date.now()
      if (timer !== null) clearTimeout(timer)
      timer = setTimeout(onTimeout, SILENCE_LIMIT_MS)
      return true
    },
    stop,
  }
}
