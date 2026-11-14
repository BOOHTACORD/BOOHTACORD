import { ref } from 'vue'
import type { MemberPresence } from './profile_client'

type PresenceEvent = { kind: string; payload: Record<string, unknown> }

export function useGuildPresence() {
  const onlineUserIDs = ref<Set<string> | null>(null)
  const idleUserIDs = ref<Set<string>>(new Set())
  const changes = ref(new Map<string, MemberPresence>())
  const unavailable = ref(false)

  function acceptRealtimeEvent(event: PresenceEvent): boolean {
    if (event.kind === 'presence.snapshot') {
      const ids = event.payload.online_user_ids
      const idle = event.payload.idle_user_ids
      const validOnline = Array.isArray(ids) && ids.every((id) => typeof id === 'string')
      const validIdle = idle === undefined || (Array.isArray(idle) && idle.every((id) => typeof id === 'string'))
      onlineUserIDs.value = validOnline && validIdle ? new Set(ids as string[]) : null
      idleUserIDs.value = validOnline && validIdle && Array.isArray(idle) ? new Set(idle) : new Set()
      changes.value = new Map()
      unavailable.value = onlineUserIDs.value === null
      return true
    }
    if (event.kind !== 'presence.changed') return false
    const userID = event.payload.user_id
    const state = event.payload.presence
    const activityState = event.payload.activity_state
    if (typeof userID === 'string' && (state === 'online' || state === 'offline')) {
      const resolved = state === 'offline' ? 'offline' : activityState === 'idle' ? 'idle' : 'online'
      changes.value = new Map(changes.value).set(userID, resolved)
    }
    return true
  }

  function resolve(userID: string, fallback: MemberPresence): MemberPresence {
    if (unavailable.value) return 'unknown'
    const changed = changes.value.get(userID)
    if (changed) return changed
    if (!onlineUserIDs.value) return fallback
    if (idleUserIDs.value.has(userID)) return 'idle'
    return onlineUserIDs.value.has(userID) ? 'online' : 'offline'
  }

  function invalidate(): void {
    onlineUserIDs.value = null
    idleUserIDs.value = new Set()
    changes.value = new Map()
    unavailable.value = true
  }

  return { acceptRealtimeEvent, invalidate, resolve }
}
