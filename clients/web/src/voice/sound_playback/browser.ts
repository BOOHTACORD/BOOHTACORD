import { defaultSound } from './pcm'
import type { SoundKind } from './queue'

export class BrowserSoundPlayer {
  constructor(private readonly volume: () => number, private readonly output: () => string = () => 'default') {}
  async play(kind: SoundKind, bytes: Uint8Array | null, signal: AbortSignal): Promise<void> {
    if (signal.aborted) return
    const source = bytes ?? defaultSound(kind)
    const url = URL.createObjectURL(new Blob([source.slice().buffer], { type: bytes ? 'audio/mpeg' : 'audio/wav' }))
    const audio = new Audio(url)
    audio.volume = Math.max(0, Math.min(1, this.volume() / 100))
    let started = false
    const stop = () => { audio.pause(); audio.removeAttribute('src'); audio.load() }
    let finish: () => void = () => {}
    const ended = new Promise<void>(resolve => { finish = resolve; audio.onended = resolve as () => void; audio.onerror = () => resolve() })
    const cancel = () => { stop(); finish() }
    signal.addEventListener('abort', cancel, { once: true })
    try {
      const target = audio as HTMLAudioElement & { setSinkId?: (id: string) => Promise<void> }
      if (target.setSinkId) await target.setSinkId(this.output())
      if (signal.aborted) return
      await audio.play(); started = true
      await Promise.race([ended, new Promise<void>(resolve => { const timer = setTimeout(resolve, 3500); ended.then(() => clearTimeout(timer)) })])
    } catch (error) { if (!started && !signal.aborted) throw error }
    finally { signal.removeEventListener('abort', cancel); stop(); URL.revokeObjectURL(url) }
  }
}
