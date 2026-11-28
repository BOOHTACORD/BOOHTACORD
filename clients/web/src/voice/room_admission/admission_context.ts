import type { ActiveVoiceSession, VoiceAdmission, RoomJoiner } from '../voice_session_types'
import type { VoiceReconnectMonitor } from '../voice_reconnect_monitor'
import type { VoiceDeafen } from '../voice_deafen'
import type { VoiceAudioProcessing } from '../voice_audio_processing'
import type { VoiceScreenSession } from '../voice_screen_session'

export interface VoiceAdmissionState {
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
