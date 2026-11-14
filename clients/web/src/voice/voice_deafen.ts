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
      try {
        if (current.microphone === 'PUBLISHED') current.microphone = await setMicrophone(current.room, false, this.processing())
        await current.room.setDeafened?.(true)
        this.deafened = true
        return current.microphone
      } catch (cause) {
        try { await current.room.setDeafened?.(false) } catch { /* retain the original failure */ }
        if (current.microphone !== 'PUBLISHED' && this.microphoneBeforeDeafen === 'PUBLISHED' && current.microphoneAllowed !== false) {
          try { current.microphone = await setMicrophone(current.room, true, this.processing()) } catch { /* keep the microphone safely muted */ }
        }
        this.microphoneBeforeDeafen = null
        throw cause
      }
    }

    const microphone = this.microphoneBeforeDeafen
    try {
      await current.room.setDeafened?.(false)
      if (microphone === 'PUBLISHED' && current.microphoneAllowed !== false) current.microphone = await setMicrophone(current.room, true, this.processing())
      this.microphoneBeforeDeafen = null
      this.deafened = false
      return current.microphone
    } catch (cause) {
      try { await current.room.setDeafened?.(true) } catch { /* retain the original failure */ }
      if (current.microphone === 'PUBLISHED') {
        try { current.microphone = await setMicrophone(current.room, false, this.processing()) } catch { /* keep local state fail-closed */ }
      }
      throw cause
    }
  }
}
