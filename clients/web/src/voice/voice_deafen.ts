import { defaultAudioProcessing, setMicrophone, type AudioProcessingOptions, type MicrophoneState, type VoiceRoom } from './livekit_gateway'

export interface DeafenableVoiceSession {
  microphone: MicrophoneState
  microphoneAllowed?: boolean
  room: VoiceRoom
}

export class VoiceDeafen {
  private deafened = false
  private microphoneBeforeDeafen: MicrophoneState | null = null

  constructor(private readonly current: () => DeafenableVoiceSession | null, private readonly processing: () => AudioProcessingOptions = () => defaultAudioProcessing) {}

  get isDeafened(): boolean {
    return this.deafened
  }

  reset(): void {
    this.deafened = false
    this.microphoneBeforeDeafen = null
  }

  invalidateMicrophoneRestore(): void {
    this.microphoneBeforeDeafen = 'MUTED'
  }

  async set(deafened: boolean): Promise<MicrophoneState> {
    const current = this.current()
    if (!current) throw new Error('Сначала подключитесь к голосовому каналу.')
    if (this.deafened === deafened) return current.microphone

    if (deafened) {
      this.microphoneBeforeDeafen = current.microphone
      if (current.microphone === 'PUBLISHED') current.microphone = await setMicrophone(current.room, false, this.processing())
      current.room.setDeafened?.(true)
      this.deafened = true
      return current.microphone
    }

    const microphone = this.microphoneBeforeDeafen
    this.microphoneBeforeDeafen = null
    current.room.setDeafened?.(false)
    this.deafened = false
    if (microphone === 'PUBLISHED' && current.microphoneAllowed !== false) current.microphone = await setMicrophone(current.room, true, this.processing())
    return current.microphone
  }
}
