import { describe, expect, it } from 'vitest'
import { groupMembersByPresence } from './member_presence'

describe('guild member presence groups', () => {
  it('groups idle members under online while preserving their idle status', () => {
    const grouped = groupMembersByPresence([
      { user_id: '1', presence: 'online' as const },
      { user_id: '2', presence: 'offline' as const },
      { user_id: '3', presence: 'unknown' as const },
      { user_id: '4', presence: 'idle' as const },
    ])

    expect(grouped.online.map((member) => member.user_id)).toEqual(['1', '4'])
    expect(grouped.online[1]?.presence).toBe('idle')
    expect(grouped.offline.map((member) => member.user_id)).toEqual(['2'])
    expect(grouped.unknown.map((member) => member.user_id)).toEqual(['3'])
    expect(Object.keys(grouped)).toEqual(['online', 'offline', 'unknown'])
  })

  it('fails closed to unknown for a missing or unrecognized wire status', () => {
    const grouped = groupMembersByPresence([
      { user_id: '4' },
      { user_id: '5', presence: 'away' as never },
    ])

    expect(grouped.unknown.map((member) => member.user_id)).toEqual(['4', '5'])
    expect(grouped.offline).toEqual([])
  })
})
