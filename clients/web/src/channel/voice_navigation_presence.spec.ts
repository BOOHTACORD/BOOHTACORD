import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'

import { buildVoiceNavigationPresence } from './voice_navigation_presence'

const idleConnection = {
  microphoneMuted: false,
  deafened: false,
  microphonePermissionDenied: false,
  selfSpeaking: false,
  voiceVolumeParticipants: [],
  screenViewerCards: [],
}

describe('active voice channel navigation presence', () => {
  it('does not invent room members when there is no active connection', () => {
    expect(buildVoiceNavigationPresence(null, null, idleConnection)).toBeNull()
  })

  it('combines the local state with only live participants and their screen shares', () => {
    const presence = buildVoiceNavigationPresence('room-1', {
      account_id: 'account-self',
      display_name: 'Алекс',
    }, {
      ...idleConnection,
      selfSpeaking: true,
      voiceVolumeParticipants: [
        { id: 'remote-1', accountId: 'account-1', name: 'Мика', microphoneMuted: false, deafened: true, speaking: true, volume: 100 },
        { id: 'remote-2', accountId: 'account-2', name: 'Дима', microphoneMuted: true, deafened: false, speaking: false, volume: 100 },
      ],
      screenViewerCards: [
        { id: 'local-share', accountId: 'account-self', hasAudio: true, isLocal: true, participantId: 'local-identity', participantName: 'Алекс' },
        { id: 'remote-share', accountId: 'account-2', hasAudio: false, isLocal: false, participantId: 'remote-2', participantName: 'Дима' },
      ],
    })

    expect(presence?.memberCount).toBe(3)
    expect(presence?.members).toMatchObject([
      { id: 'account-1', name: 'Мика', self: false, speaking: true, isSpeaking: false, microphoneMuted: false, deafened: true, screenSharing: false },
      { id: 'account-2', name: 'Дима', self: false, speaking: false, microphoneMuted: true, screenSharing: true },
      { id: 'account-self', name: 'Алекс', self: true, speaking: true, screenSharing: true },
    ])
  })

  it('binds the roster to the connected channel and status component', () => {
    const navigation = readFileSync(new URL('./ChannelNavigation.vue', import.meta.url), 'utf8')
    const workspace = readFileSync(new URL('../workspace/WorkspaceApp.vue', import.meta.url), 'utf8')

    expect(workspace).toContain(':voice-presence="voiceNavigationPresence"')
    expect(navigation).toContain('props.voicePresence && props.voicePresence.channelId === channel.id')
    expect(navigation).toContain('<VoiceParticipantStatus')
    expect(navigation).toContain('member.screenSharing')
  })
})
