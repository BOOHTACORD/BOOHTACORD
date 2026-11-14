import { describe, expect, it } from 'vitest'
import { useGuildPresence } from './guild_presence'

describe('idle guild presence', () => {
  it('keeps idle users connected and resolves them to a separate state', () => {
    const presence = useGuildPresence()
    presence.acceptRealtimeEvent({
      kind: 'presence.snapshot',
      payload: { online_user_ids: ['user-1', 'user-2'], idle_user_ids: ['user-2'] },
    })
    expect(presence.resolve('user-1', 'unknown')).toBe('online')
    expect(presence.resolve('user-2', 'unknown')).toBe('idle')
    expect(presence.resolve('user-3', 'unknown')).toBe('offline')
  })

  it('moves between active, idle and offline from realtime updates', () => {
    const presence = useGuildPresence()
    presence.acceptRealtimeEvent({ kind: 'presence.snapshot', payload: { online_user_ids: ['user-1'], idle_user_ids: [] } })
    presence.acceptRealtimeEvent({ kind: 'presence.changed', payload: { user_id: 'user-1', presence: 'online', activity_state: 'idle' } })
    expect(presence.resolve('user-1', 'unknown')).toBe('idle')
    presence.acceptRealtimeEvent({ kind: 'presence.changed', payload: { user_id: 'user-1', presence: 'online', activity_state: 'active' } })
    expect(presence.resolve('user-1', 'unknown')).toBe('online')
    presence.acceptRealtimeEvent({ kind: 'presence.changed', payload: { user_id: 'user-1', presence: 'offline' } })
    expect(presence.resolve('user-1', 'unknown')).toBe('offline')
  })
})
