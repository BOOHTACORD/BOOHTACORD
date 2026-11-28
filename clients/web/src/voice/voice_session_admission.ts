import type { ActiveVoiceSession, VoiceAdmission } from './voice_session_types'
import type { VoiceAdmissionState } from './room_admission/admission_context'
import { assertJoinIntent } from './room_admission/intent'
import type { VoiceJoinMode } from './livekit_gateway'
import type { AudioInputSelection } from './audio_input_selection'
import { tracedOperation } from '../telemetry/client_tracing'
import { activeAction } from '../telemetry/action_scope/scope'
import { telemetrySession } from '../telemetry/action_scope/session'
import { cleanupFailedVoiceJoin } from './admission_cleanup/cleanup'

export class VoiceSessionAdmission {
  private readonly disconnectingRooms = new WeakSet<ActiveVoiceSession['room']>()

  constructor(private readonly state: VoiceAdmissionState) {}

  async join(
    channelId: string,
    transfer: boolean,
    joinMode: VoiceJoinMode,
    isCurrent?: () => boolean,
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
        let credential = await within(() => this.state.admission.credential(acquired.id))
        const options = { current: isCurrent, refreshCredential: async () => {
          assertJoinIntent({ current: isCurrent })
          credential = await within(() => this.state.admission.credential(acquired.id))
          return credential
        } }
        assertJoinIntent(options)
        const effectiveJoinMode = joinMode === 'listener' || credential.microphoneAllowed === false
          ? 'listener'
          : 'with-microphone'
        action?.step('connect')
        const joined = await within(() => this.state.joinRoom(
          credential,
          this.state.audioProcessing.value,
          effectiveJoinMode,
          this.state.inputDeviceId(),
          options,
        ))
        joinedRoom = joined.room
        assertJoinIntent(options)
        const current: ActiveVoiceSession = {
          listenerOnly: effectiveJoinMode === 'listener' || credential.microphoneAllowed === false,
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
        await cleanupFailedVoiceJoin(this.state, joinedRoom, () => lease ? within(() => this.state.admission.release(lease!.id)) : Promise.resolve())
        throw cause
      }
    })
  }

  async handleDisconnected(room: ActiveVoiceSession['room'], reason?: number): Promise<void> {
    const current = this.state.current()
    if (!current || current.room !== room || this.disconnectingRooms.has(room)) return
    this.disconnectingRooms.add(room)
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
