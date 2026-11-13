import type { RealtimeSocket } from './realtime_connection_types'
import { HEARTBEAT_PROTOCOL } from './liveness'

// Browsers reject a handshake when a requested protocol is not selected.
// Alternate only after a failed handshake; retry modern negotiation after any
// established connection closes so upgraded servers gain liveness checks.
export function createProtocolFallback() {
  let offer = true
  const opened = new WeakSet<RealtimeSocket>()
  return {
    open(url: string): RealtimeSocket {
      return offer ? new WebSocket(url, HEARTBEAT_PROTOCOL) : new WebSocket(url)
    },
    connected(socket: RealtimeSocket): void { opened.add(socket) },
    failed(socket: RealtimeSocket): void { offer = opened.has(socket) ? true : !offer },
  }
}
