import type { RealtimeEvent } from '../realtime/realtime_client'
import type { useMemberDirectory } from '../identity/member_directory'

export function reconcilePresenceMembers(event: RealtimeEvent, members: ReturnType<typeof useMemberDirectory>): Promise<void> | undefined {
  if (event.kind === 'presence.changed' && event.payload.presence === 'online' && typeof event.payload.user_id === 'string') {
    return members.ensureMember(event.payload.user_id)
  }
  if (event.kind === 'presence.snapshot' && Array.isArray(event.payload.online_user_ids)) {
    const ids = [...new Set(event.payload.online_user_ids.filter((value): value is string => typeof value === 'string'))]
    const initial = members.members.length ? Promise.resolve() : members.refresh()
    return initial.then(() => Promise.all(ids.slice(0, 33).map(id => members.ensureMember(id)))).then(() => undefined)
  }
}
