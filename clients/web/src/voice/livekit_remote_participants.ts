import { RemoteParticipantController, type RemoteMicrophonePublication, type SpeakingPlayback } from './remote_participant_controller'
import { remoteParticipantDeafened } from './voice_deafen_attribute'
import type { ScreenViewerPublication } from './screen_viewer_controller'

export interface LiveKitRemoteParticipant {
  attributes?: Readonly<Record<string, string>>
  getTrackPublication(source: unknown): ScreenViewerPublication | undefined
  identity: string
  metadata?: string
  name?: string
}

export function bindLiveKitRemoteParticipants(
  participants: () => Iterable<LiveKitRemoteParticipant>,
  microphoneSource: unknown,
  participantId: (participant: LiveKitRemoteParticipant) => string,
  accountId: (participant: LiveKitRemoteParticipant) => string | null,
  playback: SpeakingPlayback,
): RemoteParticipantController {
  return new RemoteParticipantController(() => [...participants()].map((participant) => ({
    accountId: accountId(participant),
    deafened: remoteParticipantDeafened(participant.attributes),
    id: participantId(participant),
    microphone: participant.getTrackPublication(microphoneSource) as RemoteMicrophonePublication | undefined,
    name: participant.name,
  })), playback)
}
