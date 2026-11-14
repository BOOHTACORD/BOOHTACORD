import {
  setMicrophone,
  type AudioProcessingOptions,
  type MicrophoneState,
} from './media_publishing'
import type { ActiveVoiceSession } from './voice_session_types'
import type { VoiceDeafen } from './voice_deafen'
import type { VoiceAudioProcessing } from './voice_audio_processing'
import type { AudioDeviceKind } from './audio_devices'
import type { AudioInputSelection } from './audio_input_selection'
import { reportAudioInputSwitch } from './audio_input_reporting'

interface VoiceSessionControlState {
  current(): ActiveVoiceSession | null
  setInputDeviceId(deviceId: string): void
  inputSelection(): AudioInputSelection
  audioProcessing: VoiceAudioProcessing
  deafen: VoiceDeafen
}

export class VoiceSessionControls {
  constructor(private readonly state: VoiceSessionControlState) {}

  async setMicrophoneMuted(muted: boolean): Promise<MicrophoneState> {
    const current = this.state.current()
    if (!current) throw new Error('Сначала подключитесь к голосовому каналу.')
    if (!muted && current.microphoneAllowed === false) return current.microphone
    if (this.state.deafen.isDeafened && !muted) return current.microphone
    const microphone = await setMicrophone(current.room, !muted, this.state.audioProcessing.value)
    if (this.state.current() !== current) throw new Error('Голосовое подключение закрыто.')
    current.microphone = microphone
    if (microphone === 'PUBLISHED') current.listenerOnly = false
    return microphone
  }

  setDeafened(deafened: boolean): Promise<MicrophoneState> {
    return this.state.deafen.set(deafened)
  }

  async setAudioProcessing(options: AudioProcessingOptions): Promise<void> {
    await this.state.audioProcessing.set(options)
  }

  async switchAudioDevice(kind: AudioDeviceKind, deviceId: string): Promise<AudioInputSelection | undefined> {
    const current = this.state.current()
    if (!current) {
      if (kind !== 'audioinput') throw new Error('Сначала подключитесь к голосовому каналу.')
      this.state.setInputDeviceId(deviceId)
      reportAudioInputSwitch('prejoin', 'success')
      return this.state.inputSelection()
    }
    if (kind === 'audioinput') {
      const selected = this.state.inputSelection()
      if (selected.deviceId === deviceId && selected.outcome !== 'error') return selected
    }
    try {
      const switched = await current.room.switchActiveDevice(kind, deviceId)
      if (this.state.current() !== current) throw new Error('Голосовое подключение закрыто.')
      if (!switched && (kind !== 'audioinput' || !current.room.readAudioInputSelection)) {
        throw new Error('Браузер не смог переключить выбранное аудиоустройство.')
      }
      if (kind === 'audioinput') {
        this.state.setInputDeviceId(current.room.readAudioInputSelection?.().deviceId ?? deviceId)
        return this.state.inputSelection()
      }
    } catch (cause) {
      if (this.state.current() !== current) throw new Error('Голосовое подключение закрыто.')
      const selection = kind === 'audioinput' ? current.room.readAudioInputSelection?.() : undefined
      if (selection?.outcome === 'error') {
        current.microphone = 'MUTED'
        this.state.deafen.invalidateMicrophoneRestore()
        return selection
      }
      throw cause
    }
  }
}
