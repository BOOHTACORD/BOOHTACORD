import { defineStore } from 'pinia'
import { computed,onScopeDispose,ref,shallowRef,watch } from 'vue'
import { createVoiceDisconnectState } from '../disconnect_notice/state'
import { VoiceSession,type ActiveVoiceSession } from '../voice_session'
import { installVoiceConnectionLifecycle } from '../connection_lifecycle'
import { leaveVoiceConnection } from '../voice_connection_leave'
import { createVoiceConnectionRevocation } from '../voice_connection_revocation'
import { createProcessingState } from './processing'
import { createConnectionStats } from './stats'
import { createVoiceMediaState } from './media'
import { createConnectionJoin } from './join'
import type { VoiceConnectionState } from './types'
import type { VoiceJoinMode } from '../livekit_gateway'
import { createControllerOwnership } from '../controller_ownership/state'
const session = new VoiceSession()

export const useVoiceConnectionStore = defineStore('voice-connection', () => {
  const active = shallowRef<ActiveVoiceSession | null>(null)
  const error = ref<string | null>(null)
  const terminal = createVoiceDisconnectState()
  onScopeDispose(terminal.reset)
  const microphoneMuted = ref(false)
  const microphonePermissionDenied = ref(false)
  const deafened = ref(false)
  const transferRequired = ref(false)
  const {microphoneTrack,inputSelection,audioProcessingDiagnostics,refreshAudioProcessingDiagnostics,setAudioProcessing,switchAudioDevice,setInputDevice}=createProcessingState(session,active,microphoneMuted)
  const state = ref<VoiceConnectionState>('IDLE')
  const canJoin = computed(() => (state.value === 'IDLE' || state.value === 'ERROR') && terminal.notice.value?.reconnectAllowed !== false)
  const {voiceAudioDiagnostics,connectionQuality,pingMs}=createConnectionStats(active,state)
  const {screenError,screenDiagnostics,screenProfile,screenState,screenViewerError,screenViewerEnded,selectedScreenStreamId,refreshScreenDiagnostics,startScreen,stopScreen,screenViewer,refreshScreenWatchers,deafenChanging,toggleDeafen,setMicrophoneMuted,toggleMicrophone,volume,voiceVolumeParticipants,screenViewerCards,screenWatcherIds,ownerScreenWatcherIds}=createVoiceMediaState(session,active,state,error,deafened,microphoneMuted,microphonePermissionDenied)
  const revocation = createVoiceConnectionRevocation({ terminal, session, active, state, error, deafened, microphoneMuted, microphonePermissionDenied, screenDiagnostics, screenProfile, screenState, screenViewer, volume, refreshAudioProcessingDiagnostics })
  const transferChannelId=ref<string|null>(null),transferJoinMode=ref<VoiceJoinMode>('with-microphone')
  const ownership=createControllerOwnership(async()=>{await revocation.disconnectLocal('TRANSFER');return !active.value})
  const originControllerAvailable=ref(false)
  const bindControllerAccount=(id:string)=>{ownership.bind(id || null);originControllerAvailable.value=ownership.available()}
  const originControllerOwned=ownership.owned,originControllerChannel=ownership.otherChannelId
  watch(active,current=>{if(!current&&state.value!=='JOINING') void ownership.release()})
  onScopeDispose(ownership.cancel)

  installVoiceConnectionLifecycle(session, active, state, error, microphoneMuted, microphonePermissionDenied, deafened, screenDiagnostics, screenProfile, screenState, screenViewer, volume, refreshAudioProcessingDiagnostics, terminal)

  const {join,settled}=createConnectionJoin({session,terminal,revocation,active,state,error,deafened,microphoneMuted,microphonePermissionDenied,canJoin,transferRequired,screenViewer,volume,refreshAudioProcessingDiagnostics,ownership,transferChannelId,transferJoinMode})
  async function leave(): Promise<void> {
    if(state.value==='JOINING'&&!active.value){terminal.reset();state.value='LEAVING';await ownership.cancelPending();await settled();state.value='IDLE';error.value=null;transferRequired.value=false;return}
    await leaveVoiceConnection({ terminal, session, active, state, error, deafened, screenDiagnostics, screenProfile, screenState, screenViewer, volume, refreshAudioProcessingDiagnostics })
    const reason = revocation.takePostLeaveReason(active.value?.leaseId ?? '')
    if (reason && active.value) await revocation.revokeLease(active.value.leaseId, reason)
    if(!active.value) await ownership.release()
  }

  function selectDisconnectChannel(id: string): void { const old = terminal.notice.value; terminal.selectChannel(id); if (old && !terminal.notice.value) { revocation.resetPending(); error.value = null } }
  return { originControllerAvailable,bindControllerAccount,originControllerOwned,originControllerChannel,transferChannelId,transferJoinMode,disconnectNotice: terminal.notice, selectDisconnectChannel, resetAudioVolumes: volume.reset, active, voiceAudioDiagnostics, audioProcessingDiagnostics, inputSelection, setInputDevice, microphoneTrack, canJoin, clearScreenStream: screenViewer.clear, connectionQuality, deafenChanging, deafened, disconnectLocal: revocation.disconnectLocal, error, join, leave, microphoneMuted, microphonePermissionDenied, pingMs, refreshScreenDiagnostics, refreshScreenWatchers, retryScreenStream: screenViewer.retry, revokeLease: revocation.revokeLease, screenDiagnostics, screenError, screenProfile, screenState, screenViewerCards, screenViewerEnded, screenViewerError, screenWatcherIds, ownerScreenWatcherIds, selectScreenStream: screenViewer.select, selectedScreenStreamId, screenAudioMuted: screenViewer.audioMuted, setAudioProcessing, setMicrophoneMuted, startScreen, state, stopScreen, switchAudioDevice, toggleDeafen, toggleMicrophone, toggleScreenAudio: () => screenViewer.toggleAudio(volume.selectedScreenVolume.value, volume.setScreenVolume), transferRequired, voiceVolumeError: volume.error, voiceVolumeParticipants, selfSpeaking: volume.selfSpeaking, selectedScreenAudioVolume: volume.selectedScreenVolume, setParticipantVolume: volume.setParticipantVolume, setScreenVolume: volume.setScreenVolume }
})
