import type { Ref } from 'vue'
import type { VoiceDisconnectState } from './disconnect_notice/state'
import { journeyRecorder } from '../telemetry/journey_intervals/runtime'
import type { Outcome } from '../telemetry/journey_intervals/state'

import type { VoiceConnectionState } from './connection_store'
import { unknownScreenDiagnostics, type ScreenDiagnostics } from './screen_diagnostics'
import type { ScreenShareState } from './screen_controls'
import type { ScreenProfile } from './livekit_gateway'
import type { ActiveVoiceSession, VoiceSession } from './voice_session'
import type { VoiceRecoveryTarget } from './connection_state/recovery'

interface Stoppable { stop(): void }

export function installVoiceConnectionLifecycle(
  session: Pick<VoiceSession, 'setConnectionObserver'>,
  active: Ref<ActiveVoiceSession | null>,
  state: Ref<VoiceConnectionState>,
  error: Ref<string | null>,
  microphoneMuted: Ref<boolean>,
  microphonePermissionDenied: Ref<boolean>,
  deafened: Ref<boolean>,
  screenDiagnostics: Ref<ScreenDiagnostics>,
  screenProfile: Ref<ScreenProfile | null>,
  screenState: Ref<ScreenShareState>,
  screenViewer: Stoppable,
  volume: Stoppable,
  refreshAudioProcessingDiagnostics: () => void,
  terminal?: VoiceDisconnectState,
  unexpectedDisconnect?: (target: VoiceRecoveryTarget) => void,
): void {
  let reconnect:((outcome:Outcome)=>void)|null=null
  session.setConnectionObserver({
    admitted: (leaseID, channelID) => {reconnect?.('cancelled');reconnect=null;terminal?.bind(leaseID,channelID)},
    reconnecting: () => {
      if (active.value && state.value !== 'LEAVING' && !terminal?.notice.value) {
        reconnect ??= journeyRecorder.begin('reconnect_recovered')
        state.value = 'RECONNECTING'
        error.value = null
      }
    },
    reconnected: () => {
      reconnect?.(active.value&&!terminal?.notice.value?'completed':'cancelled');reconnect=null
      if (active.value && !terminal?.notice.value) state.value = active.value.microphone === 'PUBLISHED' ? 'CONNECTED' : 'LISTENER'
    },
    disconnected: () => {
      reconnect?.('failed');reconnect=null
      const disconnected = active.value
      const wasDeafened = deafened.value
      const wasMuted = microphoneMuted.value
      if (disconnected) terminal?.bind(disconnected.leaseId, disconnected.channelId)
      const isTransport = !terminal?.notice.value && Boolean(disconnected && unexpectedDisconnect)
      if (!isTransport) terminal?.transport()
      screenViewer.stop()
      volume.stop()
      active.value = null
      refreshAudioProcessingDiagnostics()
      deafened.value = false
      microphoneMuted.value = false
      microphonePermissionDenied.value = false
      screenDiagnostics.value = unknownScreenDiagnostics()
      screenProfile.value = null
      screenState.value = 'IDLE'
      state.value = isTransport ? 'RECONNECTING' : terminal?.notice.value?.source === 'local' ? 'IDLE' : 'ERROR'
      error.value = isTransport || terminal?.notice.value?.source === 'local' ? null : terminal?.notice.value?.message ?? 'Голосовое соединение не восстановлено. Подключитесь снова вручную.'
      if (isTransport && disconnected) unexpectedDisconnect?.({
        channelId: disconnected.channelId,
        leaseId: disconnected.leaseId,
        joinMode: disconnected.listenerOnly || disconnected.microphone !== 'PUBLISHED' || wasMuted || wasDeafened ? 'listener' : 'with-microphone',
        deafened: wasDeafened,
      })
    },
  })
}
