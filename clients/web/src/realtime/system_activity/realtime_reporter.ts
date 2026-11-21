import type { RealtimeSocket } from '../realtime_connection_types'
import { createActivityThrottle } from './throttle'

export function createRealtimeActivityReporter() {
  const throttle = createActivityThrottle()
  let enabled: () => boolean = () => false
  let initialIdle: () => boolean = () => false
  let confirmedSocket: RealtimeSocket | null = null, inactiveSocket: RealtimeSocket | null = null
  function target(base: string): { url: string; confirmed: boolean } {
    if (!enabled()) return { url: base, confirmed: false }
    const parsed = new URL(base)
    const capabilities = parsed.searchParams.get('capabilities')?.split(',').filter(Boolean) ?? []
    if (!capabilities.includes('confirmed_activity_v1')) capabilities.push('confirmed_activity_v1')
    if (initialIdle() && !capabilities.includes('initial_idle_v1')) capabilities.push('initial_idle_v1')
    parsed.searchParams.set('capabilities', capabilities.join(','))
    return { url: parsed.toString(), confirmed: true }
  }
  function report(socket: RealtimeSocket | null, connected: boolean) {
    if (!connected || !socket?.send || !throttle.ready()) return
    try { socket.send(JSON.stringify({ type: 'activity' })); throttle.sent() } catch { /* Retry on a later observation. */ }
  }
  function inactive(socket: RealtimeSocket | null, connected: boolean) {
    if (!connected || !socket?.send || confirmedSocket !== socket || inactiveSocket === socket) return
    try { socket.send(JSON.stringify({ type: 'inactive' })); inactiveSocket = socket } catch { /* Retry on a later observation. */ }
  }
  return { target, report, inactive,
    setEnabled: (value: (() => boolean) | null, idle: (() => boolean) | null = null) => {
      enabled = value ?? (() => false); initialIdle = idle ?? (() => false)
    },
    attach: (socket: RealtimeSocket, confirmed: boolean) => { confirmedSocket = confirmed ? socket : null },
  }
}
