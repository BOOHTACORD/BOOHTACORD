import { SoundBurstLimit } from '../sound_events/limit'
import { boundedCustom, type CustomLoader } from './custom'

export type SoundKind = 'joined' | 'left' | 'started' | 'stopped'
export type SoundRequest = { type: SoundKind; customId?: string }
// The driver must reject custom decoding before starting audio; after starting it
// must resolve on completion or abort. This prevents a fallback over live audio.
export type PlaybackPort = { load: CustomLoader; play: (type: SoundKind, bytes: Uint8Array | null, signal: AbortSignal) => Promise<void> }

export class SoundPlaybackQueue {
  private pending: { request: SoundRequest; time: number } | null = null
  private running = false
  private active: AbortController | null = null
  private readonly limit = new SoundBurstLimit()
  constructor(private readonly port: PlaybackPort, private readonly allowed: (type: SoundKind) => boolean, private readonly deadlineMs = 300) {}

  submit(request: SoundRequest): void {
    if (!this.allowed(request.type)) return
    const item = { request: { ...request }, time: Date.now() }
    if (this.running) { this.pending ??= item; return }
    void this.run(item)
  }
  clear(): void { this.pending = null; this.active?.abort() }
  private async run(item: { request: SoundRequest; time: number }): Promise<void> {
    if (!this.allowed(item.request.type) || Date.now() - item.time > 5000 || !this.limit.allow(Date.now())) return
    this.running = true
    const controller = new AbortController()
    this.active = controller
    try {
      let bytes: Uint8Array | null = null
      if (item.request.type === 'joined' && item.request.customId) bytes = await boundedCustom(this.port.load, item.request.customId, controller.signal, this.deadlineMs)
      if (controller.signal.aborted || !this.allowed(item.request.type) || Date.now() - item.time > 5000) return
      try { await this.port.play(item.request.type, bytes, controller.signal) }
      catch {
        if (bytes && !controller.signal.aborted && this.allowed(item.request.type) && Date.now() - item.time <= 5000) await this.port.play(item.request.type, null, controller.signal)
      }
    } catch { /* Sound failures must not interrupt the voice session. */ }
    finally {
      if (this.active === controller) this.active = null
      this.running = false
      const next = this.pending; this.pending = null
      if (next) void this.run(next)
    }
  }
}
