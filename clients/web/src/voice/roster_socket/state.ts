import { ref } from 'vue'
import type { RealtimeEvent } from '../../realtime/realtime_client'
import { validVoiceRosterRealtime } from '../../realtime/roster_payload'
import { parseVoiceRosters, type VoiceRoomRoster } from '../voice_roster_client'
import { registerVoiceRosterRetry } from '../roster_status/retry_action'

export type RosterStatus = 'initial_loading' | 'fresh' | 'fresh_empty' | 'stale_reconnecting' | 'unavailable'

export function createRosterSocketState(reconnectSocket: () => void) {
  const channels = ref<VoiceRoomRoster[] | null>(null)
  const error = ref<string | null>(null)
  const status = ref<RosterStatus>('initial_loading')
  const lastUpdatedAt = ref<number | null>(null)
  let active = false, socket = false, generation: string | null = null, revision = 0
  let staleTimer: ReturnType<typeof setTimeout> | null = null
  let initialTimer: ReturnType<typeof setTimeout> | null = null
  let unregister: (() => void) | null = null

  function clearTimer(): void { if (staleTimer !== null) clearTimeout(staleTimer); staleTimer = null }
  function clearInitial(): void { if (initialTimer !== null) clearTimeout(initialTimer); initialTimer = null }
  function unavailable(): void {
    error.value = 'Не удалось обновить состав голосовых каналов.'
    status.value = channels.value === null ? 'unavailable' : 'stale_reconnecting'
    if (channels.value !== null && staleTimer === null) {
      staleTimer = setTimeout(() => { channels.value = null; status.value = 'unavailable'; staleTimer = null }, 10_000)
    }
  }
  function accept(event: RealtimeEvent): boolean {
    if (event.kind !== 'voice.roster.snapshot' && event.kind !== 'voice.roster.unavailable') return false
    if (!active || !socket) return true
    clearInitial()
    if (!validVoiceRosterRealtime(event.kind, event.payload) || event.kind === 'voice.roster.unavailable') { unavailable(); return true }
    const nextGeneration = event.payload.generation as string, nextRevision = event.payload.revision as number
    if (generation === nextGeneration && (nextRevision < revision ||
      (nextRevision === revision && status.value !== 'stale_reconnecting' && status.value !== 'unavailable'))) return true
    try {
      const next = parseVoiceRosters(event.payload)
      generation = nextGeneration; revision = nextRevision
      channels.value = next; lastUpdatedAt.value = Date.now()
      status.value = next.length ? 'fresh' : 'fresh_empty'; error.value = null; clearTimer()
    } catch { unavailable() }
    return true
  }
  function reconnect(): void { if (active) { unavailable(); reconnectSocket() } }
  function start(): void { if (!active) { active = true; unregister = registerVoiceRosterRetry(reconnect) } }
  function socketStart(): void {
    if (active) {
      socket = true; generation = null; revision = 0; clearInitial()
      initialTimer = setTimeout(() => { initialTimer = null; if (active && socket) unavailable() }, 10_000)
    }
  }
  function socketEnd(): void { if (active && socket) { socket = false; clearInitial(); unavailable() } }
  function stop(): void {
    active = false; socket = false; generation = null; revision = 0
    unregister?.(); unregister = null; clearTimer(); clearInitial()
    channels.value = null; error.value = null; status.value = 'initial_loading'; lastUpdatedAt.value = null
  }
  return { channels, error, status, lastUpdatedAt, accept, start, stop, socketStart, socketEnd, reconnect }
}
