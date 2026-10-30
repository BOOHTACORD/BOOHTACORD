import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'

const consumers = [
  '../channel/ChannelNavigation.vue',
  '../workspace/WorkspaceUserFooter.vue',
  '../admin/members/AdminMembersSection.vue',
  '../workspace/WorkspaceMembersPanel.vue',
  '../workspace/GuildPresenceGroup.vue',
  '../workspace/MemberPopover.vue',
  '../voice/VoiceParticipantVolumes.vue',
  '../voice/VoiceRoomRoster.vue',
]

describe('V2 fallback avatar foreground', () => {
  it.each(consumers)('uses the matching handoff tone in %s', (path) => {
    const source = readFileSync(new URL(path, import.meta.url), 'utf8')
    const backgrounds = source.match(/avatarBackground\(/g) ?? []
    const foregrounds = source.match(/avatarForeground\(/g) ?? []
    expect(backgrounds.length).toBeGreaterThan(0)
    expect(foregrounds.length).toBe(backgrounds.length)
    expect(source).toContain('color: avatarForeground(')
  })
})
