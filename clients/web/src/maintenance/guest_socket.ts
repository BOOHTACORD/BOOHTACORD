import { apiBaseUrl } from '../config/runtime'
import { parseRealtimeEvent, type RealtimeLocation } from '../realtime/realtime_client'
import type { RealtimeSocket, RealtimeSocketFactory } from '../realtime/realtime_connection_types'
import { createReconnectSchedule } from '../realtime/reconnect_schedule/controller'
import type { createMaintenanceState } from './state'
import { createLivenessWatch, HEARTBEAT_PROTOCOL } from '../realtime/liveness'
import { createProtocolFallback } from '../realtime/protocol_fallback'

type MaintenanceState = ReturnType<typeof createMaintenanceState>

export function createGuestMaintenanceSocket(
  state: MaintenanceState,
  factory?: RealtimeSocketFactory,
  location: RealtimeLocation = window.location,
  random?: () => number,
) {
  let active = false, socket: RealtimeSocket | null = null, owner = 0
  const protocol = factory ? null : createProtocolFallback()
  let timeout: ReturnType<typeof setTimeout> | null = null
  let liveness: ReturnType<typeof createLivenessWatch> | null = null
  const retry = createReconnectSchedule(open, random)
  const url = `${location.protocol === 'https:' ? 'wss:' : 'ws:'}//${location.host}${apiBaseUrl}/public/realtime`

  function clearTimeoutIfNeeded(): void { if (timeout !== null) clearTimeout(timeout); timeout = null }
  function detach(current: RealtimeSocket): void {
    current.onopen = null; current.onmessage = null; current.onerror = null; current.onclose = null
  }
  function fail(current: RealtimeSocket): void {
    if (socket !== current) return
    protocol?.failed(current)
    socket = null
    liveness?.stop(); liveness = null
    clearTimeoutIfNeeded()
    state.disconnected(owner)
    detach(current)
    current.close()
    if (active) retry.schedule()
  }
  function open(): void {
    if (!active || socket) return
    owner = state.begin()
    let current: RealtimeSocket
    try { current = (factory ?? protocol!.open)(url) } catch { state.disconnected(owner); retry.schedule(); return }
    socket = current
    liveness = createLivenessWatch(current, () => fail(current))
    let ready = false
    timeout = setTimeout(() => fail(current), 3000)
    current.onopen = () => { if (socket === current) protocol?.connected(current) }
    current.onmessage = message => {
      if (socket !== current) return
      try {
        const event = parseRealtimeEvent(JSON.parse(message.data))
        if (event.kind === 'connection.ready' && !ready && Object.keys(event.payload).length === 0) { ready = true; liveness?.observe(event.kind); return }
        if (event.kind === 'connection.heartbeat' && ready && current.protocol === HEARTBEAT_PROTOCOL) { liveness?.observe(event.kind); return }
        if (!ready || (event.kind !== 'maintenance.snapshot' && event.kind !== 'maintenance.changed')) { fail(current); return }
        const applied = state.accept(owner, event)
        if (applied) liveness?.observe(event.kind)
        if (event.kind === 'maintenance.snapshot') {
          if (!applied) { fail(current); return }
          clearTimeoutIfNeeded(); retry.ready()
        } else if (!state.known.value) fail(current)
      } catch { fail(current) }
    }
    current.onerror = () => fail(current)
    current.onclose = () => fail(current)
  }
  return {
    start(): void { if (!active) { active = true; open() } },
    stop(): void {
      active = false; retry.stop(); clearTimeoutIfNeeded()
      liveness?.stop(); liveness = null
      const current = socket; socket = null
      state.disconnected(owner)
      if (current) { detach(current); current.close() }
    },
  }
}
