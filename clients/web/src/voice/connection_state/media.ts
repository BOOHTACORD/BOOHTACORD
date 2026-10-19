import { computed,onScopeDispose,ref,watch,type Ref } from 'vue'
import type { ActiveVoiceSession,VoiceSession } from '../voice_session'
import type { VoiceConnectionState } from './types'
import { useAuthorDirectory } from '../../identity/author_directory'
import { createScreenControls,type ScreenShareState } from '../screen_controls'
import { unknownScreenDiagnostics,type ScreenDiagnostics } from '../screen_diagnostics'
import type { ScreenProfile } from '../livekit_gateway'
import { createScreenViewerControls } from '../screen_viewer_controls'
import type { ScreenViewerCard } from '../screen_viewer_controller'
import { createDeafenControls } from '../deafen_controls'
import { createMicrophoneControls } from '../microphone_controls'
import { createVoiceVolumeControls } from '../voice_volume_controls'
import { voiceParticipantName } from '../voice_participant_name'
import { observeStreamStarts } from '../stream_start_runtime'
import { installScreenSenderReporting } from '../screen_sender_reporting'
export function createVoiceMediaState(session:VoiceSession,active:Ref<ActiveVoiceSession|null>,state:Ref<VoiceConnectionState>,error:Ref<string|null>,deafened:Ref<boolean>,microphoneMuted:Ref<boolean>,microphonePermissionDenied:Ref<boolean>) {
  const screenError = ref<string | null>(null)
  const screenDiagnostics = ref<ScreenDiagnostics>(unknownScreenDiagnostics())
  const screenProfile = ref<ScreenProfile | null>(null)
  const screenState = ref<ScreenShareState>('IDLE')
  const rawScreenViewerCards = ref<ScreenViewerCard[]>([])
  const rawScreenWatcherIds = ref<string[]>([])
  const rawOwnerScreenWatcherIds = ref<string[]>([])
  const screenViewerError = ref<string | null>(null)
  const screenViewerEnded = ref(false)
  const selectedScreenStreamId = ref<string | null>(null)
  const { dispose: disposeScreenControls, refreshScreenDiagnostics, startScreen, stopScreen } = createScreenControls(session.screen, active, screenError, screenProfile, screenState, screenDiagnostics)
  onScopeDispose(disposeScreenControls)
  installScreenSenderReporting(screenState, screenDiagnostics, refreshScreenDiagnostics, undefined, () => screenProfile.value)
  const screenViewer = createScreenViewerControls(session, rawScreenViewerCards, selectedScreenStreamId, screenViewerError, screenViewerEnded, rawScreenWatcherIds, rawOwnerScreenWatcherIds)
  const { deafenChanging, toggleDeafen } = createDeafenControls(session, deafened, microphoneMuted, microphonePermissionDenied, error)
  const { setMicrophoneMuted, toggleMicrophone } = createMicrophoneControls(session, active, state, deafened, microphoneMuted, microphonePermissionDenied, error)
  const volume = createVoiceVolumeControls(session)
  onScopeDispose(volume.dispose)
  const authors = useAuthorDirectory()
  const voiceVolumeParticipants = computed(() => volume.participants.value.map((participant) => ({ ...participant, name: voiceParticipantName(authors, participant.accountId, participant.name) })))
  const screenViewerCards = computed(() => rawScreenViewerCards.value.map((stream) => ({
    ...stream, participantName: stream.isLocal ? stream.participantName : voiceParticipantName(authors, stream.accountId, stream.participantName) ?? stream.participantName,
  })))
  const screenWatcherIds = computed(() => rawScreenWatcherIds.value)
  const ownerScreenWatcherIds = computed(() => rawOwnerScreenWatcherIds.value)
  watch([rawScreenViewerCards, state], ([cards, phase]) => observeStreamStarts(cards, phase), { immediate: true, flush: 'sync' })
  let visibleAccountIds = new Set<string>()
  watch([volume.participants, rawScreenViewerCards], ([participants, streams]) => {
    const next = new Set([...participants.map((participant) => participant.accountId), ...streams.filter((stream) => !stream.isLocal).map((stream) => stream.accountId)].filter((id): id is string => Boolean(id)))
    next.forEach((id) => { if (!visibleAccountIds.has(id)) void authors.ensure(id, undefined, true) })
    visibleAccountIds = next
  }, { immediate: true })
  return {screenError,screenDiagnostics,screenProfile,screenState,screenViewerError,screenViewerEnded,selectedScreenStreamId,
    refreshScreenDiagnostics,startScreen,stopScreen,screenViewer,refreshScreenWatchers: screenViewer.refreshWatchers,deafenChanging,toggleDeafen,setMicrophoneMuted,toggleMicrophone,
    volume,voiceVolumeParticipants,screenViewerCards,screenWatcherIds,ownerScreenWatcherIds}
}
