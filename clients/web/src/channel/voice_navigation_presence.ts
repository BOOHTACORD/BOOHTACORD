import type { ScreenViewerCard } from '../voice/screen_viewer_controller'
import type { VoiceVolumeParticipant } from '../voice/voice_volume_controls'

export interface VoiceNavigationMember {
  id: string
  name: string
  microphoneMuted: boolean
  deafened: boolean
  microphoneUnavailable: boolean
  speaking: boolean
  isSpeaking: boolean
  screenSharing: boolean
  self: boolean
}

export interface VoiceNavigationPresence {
  channelId: string
  memberCount: number
  members: VoiceNavigationMember[]
}

interface VoiceNavigationProfile {
  account_id?: string
  display_name?: string | null
}

interface VoiceNavigationConnection {
  microphoneMuted: boolean
  deafened: boolean
  microphonePermissionDenied: boolean
  selfSpeaking: boolean
  voiceVolumeParticipants: VoiceVolumeParticipant[]
  screenViewerCards: ScreenViewerCard[]
}

export function buildVoiceNavigationPresence(
  channelId: string | null,
  profile: VoiceNavigationProfile | null,
  connection: VoiceNavigationConnection,
): VoiceNavigationPresence | null {
  if (!channelId) return null

  const selfMuted = connection.microphoneMuted
  const selfUnavailable = connection.microphonePermissionDenied
  const members: VoiceNavigationMember[] = [
    ...connection.voiceVolumeParticipants.map((participant) => ({
      id: participant.accountId || participant.id,
      name: participant.name?.trim() || 'Участник',
      microphoneMuted: participant.microphoneMuted,
      deafened: participant.deafened,
      microphoneUnavailable: false,
      speaking: participant.speaking,
      isSpeaking: participant.speaking && !participant.microphoneMuted && !participant.deafened,
      screenSharing: connection.screenViewerCards.some((screen) => screen.participantId === participant.id && !screen.isLocal),
      self: false,
    })),
    {
      id: profile?.account_id || 'self',
      name: profile?.display_name?.trim() || 'Вы',
      microphoneMuted: selfMuted,
      deafened: connection.deafened,
      microphoneUnavailable: selfUnavailable,
      speaking: connection.selfSpeaking,
      isSpeaking: connection.selfSpeaking && !selfMuted && !selfUnavailable && !connection.deafened,
      screenSharing: connection.screenViewerCards.some((screen) => screen.isLocal),
      self: true,
    },
  ]

  return { channelId, memberCount: members.length, members }
}
