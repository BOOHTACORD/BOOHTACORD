import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'
import { avatarBackground } from './avatar_color'

function source(path: string): string {
  return readFileSync(new URL(path, import.meta.url), 'utf8')
}

describe('GuildChat reference fidelity', () => {
  it('names the active channel in the message composer', () => {
    expect(source('../conversation/TextConversation.vue')).toContain(':placeholder="`Написать в #${channelName}`"')
  })
  it('uses the reference single-guild label and mark in the workspace header', () => {
    const app = source('../workspace/WorkspaceApp.vue')
    expect(app).toContain('<img class="guild-mark" src="/brand.png" alt="">')
    expect(app).toContain('<GuildName id="app-title" />')
    expect(app).toContain('guild-member-count')
    expect(app).toContain('@member-count="guildMemberCount = $event"')
  })

  it('uses the reference desktop columns and compact drawer instead of a squeezed roster column', () => {
    const shell = source('./shell.css') + source('./responsive_shell.css')
    expect(shell).toContain('grid-template-columns: var(--gc-layout-nav-wide) minmax(0, 1fr) var(--gc-layout-aside-wide)')
    expect(shell).toContain('grid-template-columns: var(--gc-layout-nav-wide) minmax(0, 1fr) var(--gc-layout-aside-wide)')
    expect(shell).toContain('grid-template-columns: var(--gc-layout-nav-wide) minmax(0, 1fr)')
    expect(shell).toContain('.members.is-open')
    expect(shell).toContain('.sidebar.is-open')
    expect(shell).not.toContain('208px')
  })

  it('retains the member panel data source and uses drawers for voice and narrow desktop', () => {
    const shell = source('./shell.css') + source('./responsive_shell.css')
    const app = source('../workspace/WorkspaceApp.vue')
    const actions = source('../shared/workspace_header/WorkspaceHeaderActions.vue')
    expect(app).toContain('<WorkspaceMembersPanel v-if="!selectedDirectMessage && activePanel === \'none\'"')
    expect(app).not.toContain("selectedChannel?.kind !== 'VOICE' || membersOpen")
    expect(shell).toContain('grid-template-columns: var(--gc-layout-nav-wide) minmax(0, 1fr) var(--gc-layout-aside-wide)')
    expect(shell).toContain('grid-template-columns: var(--gc-layout-nav-wide) minmax(0, 1fr) var(--gc-layout-aside-wide)')
    expect(shell).toContain('@media (min-width: 1024px) and (max-width: 1279px)')
    expect(shell).toContain('.members.is-open, .search-aside.is-open { display: block; }')
    expect(shell).not.toContain('.gc-shell.voice-room-active')
    expect(shell).not.toContain('.gc-shell.voice-members-open')
    expect(actions).toContain("membersExpanded ? 'Скрыть участников' : 'Открыть участников'")
  })

  it('gives voice and stream screens the wide PNG stage with an accessible member drawer', () => {
    const app = source('../workspace/WorkspaceApp.vue')
    const navigation = source('../workspace/workspace_navigation.ts')
    const shell = source('./responsive_shell.css')
    expect(navigation).toContain("selectedChannel.value?.kind === 'VOICE'")
    expect(app).toContain("'voice-stage-wide': voiceStageWide")
    expect(app).toContain('voiceStageWide || selectedDirectMessage')
    expect(shell).toContain('.gc-shell.voice-stage-wide .members.is-open')
    expect(shell).toContain('.gc-shell.voice-stage-wide .workspace-header-toggle--members')
    expect(shell).toContain('.gc-shell.voice-stage-wide .drawer-scrim')
  })

  it('keeps a visible mobile dock and accessible controls for opening both drawers', () => {
    const shell = source('./responsive_shell.css')
    const actions = source('../shared/workspace_header/WorkspaceHeaderActions.vue')
    const app = source('../workspace/WorkspaceApp.vue')
    expect(shell).toContain('.mobile-voice-dock')
    expect(actions).toContain("navExpanded ? 'Закрыть навигацию' : 'Открыть навигацию'")
    expect(actions).toContain("membersExpanded ? 'Скрыть участников' : 'Открыть участников'")
    expect(app).toContain('drawer-scrim')
    expect(app).toContain('toggleMembers')
  })

  it('does not expose the navigation drawer button while desktop navigation is visible', () => {
    const responsive = source('./responsive_shell.css')
    const conversation = source('./conversation.css')
    expect(responsive).toContain('.workspace-header-toggle { display: none; }')
    expect(conversation).not.toContain('.header-action { display: grid;')
    expect(conversation).toContain('.header-action:not(.workspace-header-toggle) { display: grid; }')
    expect(responsive).toContain('.workspace-header-toggle--nav, .workspace-header-toggle--members { display: grid; }')
  })

  it('shows truthful guild presence groups and only confirmed voice-room participants', () => {
    const panel = source('../workspace/WorkspaceMembersPanel.vue')
    expect(panel).toContain('useMemberDirectory')
    expect(panel).toContain('directory.refresh')
    expect(panel).toContain('groupMembersByPresence')
    expect(panel).toContain('presenceResolver')
    expect(source('../workspace/WorkspaceApp.vue')).toContain('guildPresence.resolve')
    expect(panel).toContain("selectedVoiceChannel && !voiceRoomVisible")
    expect(panel).toContain('Голосовой канал ·')
    expect(panel).toContain('voiceStateLabel')
    expect(panel).toContain('Подключитесь к каналу, чтобы увидеть его участников.')
    expect(panel).toContain('В сети')
    expect(panel).toContain('Не в сети')
    expect(panel).toContain('Статус неизвестен')
    expect(panel).not.toContain('Away')
  })

  it('keeps C-29 participant cards readable and status-visible', () => {
    const cards = source('../voice/VoiceParticipantVolumes.vue')
    const voice = source('./voice.css')
    const cardRule = voice.match(/\.participant-grid \.participant \{([^}]+)\}/)?.[1] ?? ''
    expect(cards).toContain('participant-grid')
    expect(cards).toContain('voice-participant-self')
    expect(cards).toContain('<VoiceParticipantStatus')
    expect(cardRule).toContain('min-height: 176px')
    expect(cardRule).toContain('padding: var(--gc-space-5) var(--gc-space-3) var(--gc-space-3)')
    expect(voice).toContain('minmax(160px, 1fr)')
    expect(voice).not.toContain('minmax(144px, 1fr)')
    expect(voice).toContain('overflow: auto')
  })

  it('assigns decorative avatar colors deterministically without encoding presence', () => {
    expect(avatarBackground('member-42')).toBe(avatarBackground('member-42'))
    expect(avatarBackground('member-42')).toMatch(/^var\(--gc-avatar-(blue|green|violet|orange|gray)\)$/)
  })
})
