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
import { createControllerOwnership } from '../controller_ownership/state'
import { releaseVoiceLease, VoiceRequestError } from '../admission_client'
import { tracedFetch } from '../../telemetry/client_tracing'
import type { VoiceJoinMode } from '../livekit_gateway'
import { VoiceRecoveryLoop } from './recovery'
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
  const ownership=createControllerOwnership(async()=>{await revocation.disconnectLocal('TRANSFER');return !active.value})
  let accountID: string | null = null
  const bindControllerAccount=(id:string)=>{const next=id||null;if(accountID!==next){recovery.cancel();accountID=next}ownership.bind(next)}
  watch(active,current=>{if(!current&&state.value!=='JOINING') void ownership.release()})
  onScopeDispose(ownership.cancel)

  const {join: joinInternal,settled,lastFailure}=createConnectionJoin({session,terminal,revocation,active,state,error,deafened,microphoneMuted,microphonePermissionDenied,canJoin,transferRequired,screenViewer,volume,refreshAudioProcessingDiagnostics,ownership})
  const recovery = new VoiceRecoveryLoop(async (target, current) => {
    if (!current() || terminal.notice.value?.source === 'server' || active.value) return 'stop'
    // Release the old, exact lease first. A retry never force-transfers a
    // session already acquired elsewhere while this client was offline.
    const controller = new AbortController()
    const timeout = setTimeout(() => controller.abort(), 5000)
    let released = false
    try {
      await releaseVoiceLease(target.leaseId, (url, init) => tracedFetch(url, { ...init, signal: controller.signal }))
      released = true
    } catch (cause) {
      if (cause instanceof VoiceRequestError && cause.status === 404) released = true
      if (cause instanceof VoiceRequestError && (cause.status === 401 || cause.status === 403)) return 'stop'
    } finally { clearTimeout(timeout) }
    if (!current() || terminal.notice.value?.source === 'server') return 'stop'
    if (!released) return 'retry'
    await joinInternal(target.channelId, false, target.joinMode, false, true)
    if (!current() || terminal.notice.value?.source === 'server') return 'stop'
    if (active.value?.channelId === target.channelId) {
      if (target.deafened) await toggleDeafen()
      return 'restored'
    }
    const failure = lastFailure()
    if (failure instanceof VoiceRequestError && [401, 403, 404, 409].includes(failure.status)) return 'stop'
    return 'retry'
  }, () => {
    if (!active.value && terminal.notice.value?.source !== 'server') {state.value='RECONNECTING';error.value=null}
  })
  onScopeDispose(() => recovery.cancel())
  watch(terminal.notice, notice => {if(notice?.source==='server')recovery.cancel()})

  installVoiceConnectionLifecycle(session, active, state, error, microphoneMuted, microphonePermissionDenied, deafened, screenDiagnostics, screenProfile, screenState, screenViewer, volume, refreshAudioProcessingDiagnostics, terminal, target => recovery.start(target))

  async function join(channelId:string,transfer=false,joinMode:VoiceJoinMode='with-microphone'):Promise<void> {
    if (recovery.active) {
      recovery.cancel()
      terminal.reset()
      if(state.value==='JOINING'&&!active.value){await ownership.cancelPending();await settled()}
      if(!active.value){state.value='IDLE';error.value=null}
    }
    await joinInternal(channelId,transfer,joinMode)
  }
  async function leave(): Promise<void> {
    const wasRecovering = recovery.active
    recovery.cancel()
    if(wasRecovering&&!active.value&&state.value!=='JOINING'){terminal.reset();state.value='IDLE';error.value=null;await ownership.release();return}
    if(state.value==='JOINING'&&!active.value){terminal.reset();state.value='LEAVING';await ownership.cancelPending();await settled();state.value='IDLE';error.value=null;transferRequired.value=false;return}
    await leaveVoiceConnection({ terminal, session, active, state, error, deafened, screenDiagnostics, screenProfile, screenState, screenViewer, volume, refreshAudioProcessingDiagnostics })
    const reason = revocation.takePostLeaveReason(active.value?.leaseId ?? '')
    if (reason && active.value) await revocation.revokeLease(active.value.leaseId, reason)
    if(!active.value) await ownership.release()
  }

  function selectDisconnectChannel(id: string): void { if(recovery.active&&recovery.channelId!==id){recovery.cancel();terminal.reset();if(!active.value){state.value='IDLE';error.value=null;void ownership.release()}}const old = terminal.notice.value; terminal.selectChannel(id); if (old && !terminal.notice.value) { revocation.resetPending(); error.value = null } }
  async function disconnectLocal(reason: Parameters<typeof revocation.disconnectLocal>[0]) {recovery.cancel();return revocation.disconnectLocal(reason)}
  async function revokeLease(id:string,reason:Parameters<typeof revocation.revokeLease>[1]) {recovery.cancel();return revocation.revokeLease(id,reason)}
  return { bindControllerAccount, disconnectNotice: terminal.notice, selectDisconnectChannel, resetAudioVolumes: volume.reset, active, voiceAudioDiagnostics, audioProcessingDiagnostics, inputSelection, setInputDevice, microphoneTrack, canJoin, clearScreenStream: screenViewer.clear, connectionQuality, deafenChanging, deafened, disconnectLocal, error, join, leave, microphoneMuted, microphonePermissionDenied, pingMs, refreshScreenDiagnostics, refreshScreenWatchers, retryScreenStream: screenViewer.retry, revokeLease, screenDiagnostics, screenError, screenProfile, screenState, screenViewerCards, screenViewerEnded, screenViewerError, screenWatcherIds, ownerScreenWatcherIds, selectScreenStream: screenViewer.select, selectedScreenStreamId, screenAudioMuted: screenViewer.audioMuted, setAudioProcessing, setMicrophoneMuted, startScreen, state, stopScreen, switchAudioDevice, toggleDeafen, toggleMicrophone, toggleScreenAudio: () => screenViewer.toggleAudio(volume.selectedScreenVolume.value, volume.setScreenVolume), transferRequired, voiceVolumeError: volume.error, voiceVolumeParticipants, selfSpeaking: volume.selfSpeaking, selectedScreenAudioVolume: volume.selectedScreenVolume, setParticipantVolume: volume.setParticipantVolume, setScreenVolume: volume.setScreenVolume }
})
