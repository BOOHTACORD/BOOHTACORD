import { type AudioProcessingOptions, type NoiseSuppressionFallbackReason } from '../types'

import type { MicrophoneProcessor } from './contracts'
import { MicrophoneAdapterProfile } from './profile'
export abstract class MicrophoneAdapterRecovery extends MicrophoneAdapterProfile {
  protected async changeProfile(next: AudioProcessingOptions, generation: number): Promise<void> {
    const previous = this.options
    await this.track!.mute()
    this.silence()
    try {
      await this.removeProcessor()
      await this.configure(next, generation)
      this.assertCurrent(generation)
      await this.publishMuted(generation)
      this.options = next
      await this.restoreIntent(generation)
    } catch (cause) {
      this.options = previous
      if (this.state.status === 'error' && !this.desiredEnabled) throw cause
      if (!this.closed) {
        try { await this.removeProcessor(); await this.configure(previous, generation); await this.publishMuted(generation); await this.restoreIntent(generation) }
        catch { this.failMuted() }
      }
      throw cause
    }
  }
  protected recoverProcessor(processor: MicrophoneProcessor, reason: NoiseSuppressionFallbackReason, generation: number): void {
    if (this.closed || generation !== this.generation || this.processor !== processor) return
    this.silence()
    void this.enqueue(async (current) => {
      if (this.processor !== processor) return
      try { await this.track!.mute(); await this.fallback(this.options, reason, current); await this.publishMuted(current); await this.restoreIntent(current) }
      catch { this.failMuted(reason) }
    }).catch(() => undefined)
  }
}
