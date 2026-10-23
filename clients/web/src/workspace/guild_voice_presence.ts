import type { TopologyChannel } from '../channel/topology_client'
import type { VoiceRoomRoster } from '../voice/voice_roster_client'

export interface GuildVoicePresence {
  channelName: string
  screenSharing: boolean
}

export function buildGuildVoicePresence(
  rosters: readonly VoiceRoomRoster[] | null,
  channels: readonly TopologyChannel[],
): ReadonlyMap<string, GuildVoicePresence> {
  const channelNames = new Map(channels.filter((channel) => channel.kind === 'VOICE').map((channel) => [channel.id, channel.name]))
  const members = new Map<string, GuildVoicePresence>()
  if (!rosters) return members

  for (const room of rosters) {
    const channelName = channelNames.get(room.channelId)
    if (!channelName) continue
    for (const participant of room.participants) {
      if (!members.has(participant.accountId)) {
        members.set(participant.accountId, { channelName, screenSharing: participant.screenSharing })
      }
    }
  }

  return members
}
