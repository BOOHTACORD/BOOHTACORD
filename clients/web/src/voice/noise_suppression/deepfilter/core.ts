import { SampleRingBuffer } from '../ring_buffer.js'

export interface DeepFilterEngine {
  process(frame: Float32Array): Float32Array
  reset(): void
  free(): void
}
export type DeepFilterFailure = 'invalid-audio' | 'processor-error' | 'overload'

/** Bounded 48 kHz mono reblocking; the caller owns lifecycle and fallback. */
export class DeepFilterCore {
  private readonly input = new SampleRingBuffer(1920)
  private readonly output = new SampleRingBuffer(1920)
  private readonly frame = new Float32Array(480)
  private enabled = false
  private missing = false
  private failed = false
  private disposed = false

  constructor(private readonly engine: DeepFilterEngine, private readonly onFailure: (reason: DeepFilterFailure) => void) {}

  private fail(reason: DeepFilterFailure): false {
    this.enabled = false
    if (!this.failed) { this.failed = true; this.onFailure(reason) }
    return false
  }

  private reset(): void {
    this.input.clear(); this.output.clear(); this.frame.fill(0)
    this.engine.reset()
    for (let i = 0; i < 480; i++) this.output.push(0)
  }

  setMuted(muted: boolean): boolean {
    if (this.failed || this.disposed) return false
    this.enabled = false
    try { this.reset(); this.missing = false; this.enabled = !muted; return true }
    catch { return this.fail('processor-error') }
  }

  process(source: Float32Array | undefined, destination: Float32Array): boolean {
    destination.fill(0)
    if (this.failed || this.disposed) return false
    if (!this.enabled) return true
    try {
      if (!source) {
        if (!this.missing) { this.reset(); this.missing = true }
        return true
      }
      if (source.length !== destination.length) return this.fail('processor-error')
      this.missing = false
      for (const sample of source) {
        if (!Number.isFinite(sample)) return this.fail('invalid-audio')
        if (!this.input.push(Math.max(-1, Math.min(1, sample)))) return this.fail('overload')
        if (this.input.size === 480) {
          for (let i = 0; i < 480; i++) this.frame[i] = this.input.shift()!
          const filtered = this.engine.process(this.frame)
          if (filtered.length !== 480) return this.fail('processor-error')
          for (const value of filtered) {
            if (!Number.isFinite(value)) return this.fail('invalid-audio')
            if (!this.output.push(Math.max(-1, Math.min(1, value)))) return this.fail('overload')
          }
        }
      }
      for (let i = 0; i < destination.length; i++) {
        const value = this.output.shift()
        if (value === undefined) { destination.fill(0); return this.fail('overload') }
        destination[i] = value
      }
      return true
    } catch { destination.fill(0); return this.fail('processor-error') }
  }

  dispose(): void {
    if (this.disposed) return
    this.disposed = true; this.enabled = false
    this.input.clear(); this.output.clear(); this.frame.fill(0)
    try { this.engine.free() } catch { this.fail('processor-error') }
  }
}
