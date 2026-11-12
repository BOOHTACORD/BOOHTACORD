import { RnnoiseTrackProcessorBase } from './rnnoise_track_processor_base'

/** Owns derived nodes/track only; LiveKit owns source capture and AudioContext. */
export class RnnoiseTrackProcessor extends RnnoiseTrackProcessorBase {
  private intent = 0

  mute(): void {
    this.intent++
    this.cancelUnmute?.()
    this.muted = true
    if (this.processedTrack) this.processedTrack.enabled = false
    this.worklet?.port.postMessage({ type: 'mute' })
  }

  async unmute(): Promise<void> {
    if (!this.worklet || this.failed) return
    this.cancelUnmute?.()
    const intent = ++this.intent, generation = this.generation
    await new Promise<void>((resolve, reject) => {
      const finish = (error?: Error) => {
        clearTimeout(timer); this.acknowledgeUnmute = undefined; this.cancelUnmute = undefined
        error ? reject(error) : resolve()
      }
      const timer = setTimeout(() => finish(new Error('RNNoise reset timeout')), 1000)
      this.acknowledgeUnmute = received => { if (received === intent) finish() }
      this.cancelUnmute = () => finish()
      this.worklet!.port.postMessage({ type: 'unmute', intent })
    })
    if (generation !== this.generation || intent !== this.intent || this.failed) return
    this.muted = false
    // The adapter enables the derived track after checking its latest intent.
  }
}
