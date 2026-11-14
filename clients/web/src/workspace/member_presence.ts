import type { MemberPresence } from '../identity/profile_client'

type PresenceMember = { presence?: string | null }
export type PresenceGroups<T> = Record<MemberPresence, T[]>

export function groupMembersByPresence<T extends PresenceMember>(members: readonly T[]): PresenceGroups<T> {
  const groups: PresenceGroups<T> = { online: [], idle: [], offline: [], unknown: [] }
  for (const member of members) {
    const state = member.presence === 'online' || member.presence === 'idle' || member.presence === 'offline' ? member.presence : 'unknown'
    groups[state].push(member)
  }
  return groups
}
