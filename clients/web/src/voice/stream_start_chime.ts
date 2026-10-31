import { ref, type Ref } from 'vue'

const preferenceKey = 'voice-screen-start-sound:v1'
const voiceEventsPreferenceKey = 'voice-room-event-sounds:v1'
export type VoiceRoomEventSound = 'participant-joined' | 'participant-left' | 'stream-view-started' | 'stream-view-stopped'
const voiceEventFrequencies: Record<VoiceRoomEventSound, readonly number[]> = {
  'participant-joined': [784, 988],
  'participant-left': [659, 523],
  'stream-view-started': [880, 1175],
  'stream-view-stopped': [587],
}
type Storage = Pick<globalThis.Storage, 'getItem' | 'setItem'>
type ContextFactory = () => AudioContext | null

function browserStorage(): Storage | null {
  try { return typeof localStorage === 'undefined' ? null : localStorage }
  catch { return null }
}

function browserContext(): AudioContext | null {
  try { return typeof AudioContext === 'undefined' ? null : new AudioContext() }
  catch { return null }
}

export class StreamStartChime {
  readonly enabled: Ref<boolean>
  readonly voiceEventsEnabled: Ref<boolean>
  private context: AudioContext | null = null

  constructor(private readonly createContext: ContextFactory = browserContext, private readonly storage: Storage | null = browserStorage()) {
    let saved: string | null = null
    try { saved = storage?.getItem(preferenceKey) ?? null } catch {}
    this.enabled = ref(saved !== 'off')
    let savedVoiceEvents: string | null = null
    try { savedVoiceEvents = storage?.getItem(voiceEventsPreferenceKey) ?? null } catch {}
    this.voiceEventsEnabled = ref(savedVoiceEvents !== 'off')
  }

  setEnabled(enabled: boolean): void {
    this.enabled.value = enabled
    try { this.storage?.setItem(preferenceKey, enabled ? 'on' : 'off') } catch {}
  }

  setVoiceEventsEnabled(enabled: boolean): void {
    this.voiceEventsEnabled.value = enabled
    try { this.storage?.setItem(voiceEventsPreferenceKey, enabled ? 'on' : 'off') } catch {}
  }

  activate(): void {
    if (!this.enabled.value && !this.voiceEventsEnabled.value) return
    try {
      this.context ??= this.createContext()
      if (this.context?.state === 'suspended') void this.context.resume().catch(() => undefined)
    } catch { /* Sound must never interrupt voice admission. */ }
  }

  play(): void {
    const context = this.context
    if (!this.enabled.value || !context || context.state !== 'running') return
    try {
      const oscillator = context.createOscillator()
      const gain = context.createGain()
      const start = context.currentTime
      oscillator.type = 'sine'
      oscillator.frequency.value = 880
      gain.gain.setValueAtTime(0.0001, start)
      gain.gain.exponentialRampToValueAtTime(0.045, start + 0.015)
      gain.gain.exponentialRampToValueAtTime(0.0001, start + 0.18)
      oscillator.connect(gain)
      gain.connect(context.destination)
      oscillator.onended = () => { oscillator.disconnect(); gain.disconnect() }
      oscillator.start(start)
      oscillator.stop(start + 0.19)
    } catch { /* Browser media policy leaves the visual notice available. */ }
  }

  playVoiceEvent(event: VoiceRoomEventSound): void {
    const context = this.context
    if (!this.voiceEventsEnabled.value || !context || context.state !== 'running') return
    try {
      const frequencies = voiceEventFrequencies[event]
      frequencies.forEach((frequency, index) => {
        const oscillator = context.createOscillator()
        const gain = context.createGain()
        const start = context.currentTime + index * 0.13
        oscillator.type = 'sine'
        oscillator.frequency.value = frequency
        gain.gain.setValueAtTime(0.0001, start)
        gain.gain.exponentialRampToValueAtTime(0.035, start + 0.012)
        gain.gain.exponentialRampToValueAtTime(0.0001, start + 0.105)
        oscillator.connect(gain)
        gain.connect(context.destination)
        oscillator.onended = () => { oscillator.disconnect(); gain.disconnect() }
        oscillator.start(start)
        oscillator.stop(start + 0.11)
      })
    } catch { /* Browser media policy leaves voice and screen controls available. */ }
  }
}
