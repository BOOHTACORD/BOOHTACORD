import { describe, expect, it } from 'vitest'
import type { TopologyChannel } from '../channel/topology_client'
import type { VoiceRoomRoster } from '../voice/voice_roster_client'
import { buildGuildVoicePresence } from './guild_voice_presence'

const channels: TopologyChannel[] = [
  { id: 'voice-1', name: 'Общий голосовой', kind: 'VOICE', position: 0, admissionClosed: false },
  { id: 'text-1', name: 'Общий чат', kind: 'TEXT', position: 1, admissionClosed: false },
]

describe('guild voice presence', () => {
  it('maps connected members to the voice channel and preserves their stream state', () => {
    const rosters: VoiceRoomRoster[] = [
      { channelId: 'voice-1', participants: [{ accountId: 'member-1', displayName: 'Мика', screenSharing: true, microphoneMuted: false }] },
      { channelId: 'text-1', participants: [{ accountId: 'member-2', displayName: 'Алекс', screenSharing: false, microphoneMuted: true }] },
      { channelId: 'deleted-channel', participants: [{ accountId: 'member-3', displayName: 'Дима', screenSharing: false, microphoneMuted: false }] },
    ]

    expect(buildGuildVoicePresence(rosters, channels)).toEqual(new Map([
      ['member-1', { channelName: 'Общий голосовой', screenSharing: true }],
    ]))
  })

  it('returns no voice presence when the realtime roster is unavailable', () => {
    expect(buildGuildVoicePresence(null, channels)).toEqual(new Map())
  })
})
