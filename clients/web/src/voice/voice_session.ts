import {
  acquireVoiceLease,
  issueLiveKitCredential,
  releaseVoiceLease,
} from './admission_client'
import {
  connectLiveKitRoomWithProcessing,
  type MicrophoneState, type AudioProcessingOptions, type ScreenProfile,
  type VoiceJoinMode,
} from './livekit_gateway'
import type { AudioDeviceKind } from './audio_devices'
import type { ScreenViewerController } from './screen_viewer_controller'
import { VoiceReconnectMonitor } from './voice_reconnect_monitor'
import { VoiceDeafen } from './voice_deafen'
import { VoiceAudioProcessing } from './voice_audio_processing'
import { VoiceScreenSession } from './voice_screen_session'
import type { ActiveVoiceSession, RoomJoiner, VoiceAdmission, VoiceConnectionObserver } from './voice_session_types'
import { bindBrowserVoiceResume, type BrowserVoiceRoom } from './browser_resume/lifecycle'
import type { AudioInputSelection } from './audio_input_selection'
import { VoiceSessionControls } from './voice_session_controls'
import { VoiceSessionAdmission } from './voice_session_admission'
import { VoiceSessionShutdown } from './voice_session_shutdown'
export type { ActiveVoiceSession, RoomJoiner, VoiceAdmission, VoiceConnectionObserver } from './voice_session_types'
const defaultAdmission: VoiceAdmission = {
  acquire: acquireVoiceLease,
  credential: issueLiveKitCredential,
  release: releaseVoiceLease,
}
export class VoiceSession {
  private current: ActiveVoiceSession | null = null
  private connectionObserver: VoiceConnectionObserver | null = null
  private stopBrowserVoiceResume?: () => void
  private inputDeviceId = 'default'
  private stopInputSelection?: () => void
  private readonly monitor = new VoiceReconnectMonitor()
  readonly audioProcessing = new VoiceAudioProcessing(() => this.current)
  readonly deafen = new VoiceDeafen(() => this.current, () => this.audioProcessing.value)
  readonly screen = new VoiceScreenSession(() => this.current)
  private readonly controls = new VoiceSessionControls({
    current: () => this.current,
    setInputDeviceId: (deviceId) => { this.inputDeviceId = deviceId },
    inputSelection: () => this.inputSelection,
    audioProcessing: this.audioProcessing,
    deafen: this.deafen,
  })
  private readonly admissionFlow: VoiceSessionAdmission
  private readonly shutdown: VoiceSessionShutdown
  constructor(
    private readonly admission: VoiceAdmission = defaultAdmission,
    private readonly joinRoom: RoomJoiner = connectLiveKitRoomWithProcessing,
  ) {
    this.admissionFlow = new VoiceSessionAdmission({
      current: () => this.current,
      setCurrent: (value) => { this.current = value },
      admission: this.admission,
      joinRoom: this.joinRoom,
      inputDeviceId: () => this.inputDeviceId,
      setInputDeviceId: (value) => { this.inputDeviceId = value },
      stopInputSelection: () => this.stopInputSelection,
      setStopInputSelection: (value) => { this.stopInputSelection = value },
      monitor: this.monitor,
      audioProcessing: this.audioProcessing,
      deafen: this.deafen,
      screen: this.screen,
    })
    this.shutdown = new VoiceSessionShutdown({
      current: () => this.current,
      setCurrent: (value) => { this.current = value },
      admission: this.admission,
      monitor: this.monitor,
      screen: this.screen,
      deafen: this.deafen,
      stopInputSelection: () => this.stopInputSelection,
      setStopInputSelection: (value) => { this.stopInputSelection = value },
    })
  }
  get active(): ActiveVoiceSession | null {
    return this.current
  }
  get inputSelection(): AudioInputSelection { return this.current?.room.readAudioInputSelection?.() ?? { deviceId: this.inputDeviceId, outcome: 'success' } }
  setConnectionObserver(observer: VoiceConnectionObserver): void {
    this.connectionObserver = observer
    this.monitor.setObserver({
      ...observer,
      disconnected: reason => {
        this.clearBrowserVoiceResume()
        observer.audioPlaybackChanged?.(false)
        observer.disconnected(reason)
      },
    })
  }
  screenViewer(): ScreenViewerController | null { return this.current?.room.screenViewer ?? null }
  remoteVoices() { return this.current?.room.remoteVoices ?? null }
  participantCards() { return this.current?.room.participantCards ?? null }
  async join(channelId: string, transfer = false, joinMode: VoiceJoinMode = 'with-microphone'): Promise<ActiveVoiceSession> {
    const joined = await this.admissionFlow.join(channelId, transfer, joinMode)
    this.bindBrowserVoiceResume(joined)
    return joined
  }
  async leave(): Promise<void> {
    try { await this.shutdown.leave() } finally {
      this.clearBrowserVoiceResume()
      this.connectionObserver?.audioPlaybackChanged?.(false)
    }
  }
  async revoke(leaseId: string): Promise<boolean> {
    const revoked = await this.shutdown.revoke(leaseId)
    if (revoked) {
      this.clearBrowserVoiceResume()
      this.connectionObserver?.audioPlaybackChanged?.(false)
    }
    return revoked
  }

  private bindBrowserVoiceResume(joined: ActiveVoiceSession): void {
    this.clearBrowserVoiceResume()
    const room = joined.room
    if (
      typeof document === 'undefined' || typeof window === 'undefined' ||
      !room.readConnectionState || !room.readAudioPlaybackAllowed || !room.startAudioPlayback
    ) return

    const browserRoom: BrowserVoiceRoom = {
      readConnectionState: room.readConnectionState,
      readAudioPlaybackAllowed: room.readAudioPlaybackAllowed,
      startAudioPlayback: room.startAudioPlayback,
      onAudioPlaybackStatusChanged: room.onAudioPlaybackStatusChanged,
    }
    const current = () => this.current === joined
    this.stopBrowserVoiceResume = bindBrowserVoiceResume(browserRoom, {
      onMediaState: state => {
        if (!current()) return
        if (state === 'disconnected') {
          void this.admissionFlow.handleDisconnected(room)
        } else if (state === 'reconnecting') {
          this.connectionObserver?.reconnecting()
        } else {
          this.connectionObserver?.reconnected()
        }
      },
      onAudioPlaybackAllowed: allowed => {
        if (current()) this.connectionObserver?.audioPlaybackChanged?.(!allowed)
      },
    })
  }

  private clearBrowserVoiceResume(): void {
    this.stopBrowserVoiceResume?.()
    this.stopBrowserVoiceResume = undefined
  }
  async setMicrophoneMuted(muted: boolean): Promise<MicrophoneState> {
    return this.controls.setMicrophoneMuted(muted)
  }

  async setDeafened(deafened: boolean): Promise<MicrophoneState> {
    return this.controls.setDeafened(deafened)
  }

  setAudioProcessing(options: AudioProcessingOptions): Promise<void> { return this.controls.setAudioProcessing(options) }

  async switchAudioDevice(kind: AudioDeviceKind, deviceId: string): Promise<AudioInputSelection | undefined> {
    return this.controls.switchAudioDevice(kind, deviceId)
  }

  async updateScreenProfile(profile: ScreenProfile) { return this.screen.updateScreenProfile(profile) }

}
