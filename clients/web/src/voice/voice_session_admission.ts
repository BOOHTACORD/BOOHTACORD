import type { ActiveVoiceSession, VoiceAdmission, RoomJoiner } from './voice_session_types'
import type { VoiceReconnectMonitor } from './voice_reconnect_monitor'
import type { VoiceDeafen } from './voice_deafen'
import type { VoiceAudioProcessing } from './voice_audio_processing'
import type { VoiceScreenSession } from './voice_screen_session'
import type { VoiceJoinMode } from './livekit_gateway'
import type { AudioInputSelection } from './audio_input_selection'
import { tracedOperation } from '../telemetry/client_tracing'
import { activeAction } from '../telemetry/action_scope/scope'
import { telemetrySession } from '../telemetry/action_scope/session'

interface VoiceAdmissionState {
  current(): ActiveVoiceSession | null
  setCurrent(value: ActiveVoiceSession | null): void
  admission: VoiceAdmission
  joinRoom: RoomJoiner
  inputDeviceId(): string
  setInputDeviceId(value: string): void
  stopInputSelection(): (() => void) | undefined
  setStopInputSelection(value?: () => void): void
  monitor: VoiceReconnectMonitor
  audioProcessing: VoiceAudioProcessing
  deafen: VoiceDeafen
  screen: VoiceScreenSession
}

export class VoiceSessionAdmission {
  constructor(private readonly state: VoiceAdmissionState) {}

  async join(
    channelId: string,
    transfer: boolean,
    joinMode: VoiceJoinMode,
  ): Promise<ActiveVoiceSession> {
    if (!this.state.current()) telemetrySession.beginMedia()
    return tracedOperation('voice.join', async (within) => {
      if (this.state.current()) throw new Error('Сначала завершите текущее голосовое подключение.')
      let lease: Awaited<ReturnType<VoiceAdmission['acquire']>> | null = null
      let joinedRoom: ActiveVoiceSession['room'] | null = null
      try {
        const action = activeAction()
        if (action) telemetrySession.bindMediaFlow(action.id)
        action?.step('lease')
        const acquired = await within(() => this.state.admission.acquire(channelId, transfer))
        lease = acquired
        telemetrySession.bindMediaLease(acquired.id)
        this.state.monitor.notifyAdmitted(acquired.id, acquired.channelId)
        action?.step('credential')
        const credential = await within(() => this.state.admission.credential(acquired.id))
        action?.step('connect')
        const joined = await within(() => this.state.joinRoom(
          credential,
          this.state.audioProcessing.value,
          joinMode,
          this.state.inputDeviceId(),
        ))
        joinedRoom = joined.room
        const current: ActiveVoiceSession = {
          listenerOnly: joinMode === 'listener',
          microphoneAllowed: credential.microphoneAllowed,
          channelId: acquired.channelId,
          leaseId: acquired.id,
          screenProfile: null,
          ...joined,
        }
        this.state.setCurrent(current)
        await joined.room.bindScreenPreviewLease?.(acquired.id)
        const observeInput = (selection: AudioInputSelection) => {
          if (this.state.current()?.room !== joined.room) return
          this.state.setInputDeviceId(selection.deviceId)
          if (selection.outcome === 'error') {
            current.microphone = 'MUTED'
            this.state.deafen.invalidateMicrophoneRestore()
          }
        }
        this.state.setStopInputSelection(joined.room.onAudioInputSelection?.(observeInput))
        const selected = joined.room.readAudioInputSelection?.()
        if (selected) observeInput(selected)
        this.state.monitor.bind(
          joined.room,
          () => this.state.current()?.room === joined.room,
          (reason) => this.handleDisconnected(joined.room, reason),
        )
        action?.span.setAttribute(
          'app.voice.mode',
          current.microphone === 'LISTENER_PERMISSION_DENIED'
            ? 'microphone_unavailable'
            : current.listenerOnly ? 'listener' : 'participant',
        )
        action?.step('ready')
        return current
      } catch (cause) {
        telemetrySession.endMedia()
        try { await joinedRoom?.stopScreenPreview?.() } catch { /* Release follows settled local cleanup. */ }
        if (lease) await within(() => this.state.admission.release(lease!.id)).catch(() => undefined)
        throw cause
      }
    })
  }

  async handleDisconnected(room: ActiveVoiceSession['room'], reason?: number): Promise<void> {
    const current = this.state.current()
    if (!current || current.room !== room) return
    try { await room.stopScreenPreview?.() } catch { /* Lease release follows settled local cleanup. */ }
    this.state.screen.cancel()
    this.state.stopInputSelection()?.()
    this.state.setStopInputSelection(undefined)
    this.state.setCurrent(null)
    telemetrySession.endMedia()
    this.state.deafen.reset()
    this.state.monitor.notifyDisconnected(reason)
    await this.state.admission.release(current.leaseId).catch(() => undefined)
  }
}
