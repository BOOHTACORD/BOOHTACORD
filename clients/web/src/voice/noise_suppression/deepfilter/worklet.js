import { setEntropy, releaseEntropy, withEntropy } from './worklet_env.js'
import { initSync, Denoiser } from './dfn.js'
import { DeepFilterCore } from './core.js'

class DeepFilterWorklet extends AudioWorkletProcessor {
  constructor(options) {
    super()
    this.alive = true
    let engine
    try {
      if (sampleRate !== 48000) throw new Error('sample-rate')
      const { module, model, attenuation, entropy } = options.processorOptions
      this.entropy = setEntropy(entropy)
      withEntropy(this.entropy, () => {
        initSync({ module })
        engine = new Denoiser(new Uint8Array(model), attenuation)
      })
      const scoped = {
        process: frame => withEntropy(this.entropy, () => engine.process(frame)),
        reset: () => withEntropy(this.entropy, () => engine.reset()),
        free: () => withEntropy(this.entropy, () => engine.free()),
      }
      this.core = new DeepFilterCore(scoped, reason => this.port.postMessage({ type: 'error', reason }))
      this.port.onmessage = event => {
        if (event.data.type === 'destroy') {
          this.alive = false; this.core.dispose(); releaseEntropy(this.entropy); this.port.postMessage({ type: 'destroyed' })
        } else if (event.data.type === 'mute' || event.data.type === 'unmute') {
          const muted = event.data.type === 'mute'
          if (this.core.setMuted(muted) && !muted) this.port.postMessage({ type: 'unmuted', intent: event.data.intent })
        }
      }
      this.port.postMessage({ type: 'ready', frameSize: 480 })
    } catch {
      this.alive = false
      try { if (engine) withEntropy(this.entropy, () => engine.free()) } catch { /* The module may already have trapped. */ }
      releaseEntropy(this.entropy)
      this.port.postMessage({ type: 'error', reason: 'initialization' })
    }
  }

  process(inputs, outputs) {
    const destination = outputs[0]?.[0]
    if (destination) {
      if (this.core) this.core.process(inputs[0]?.[0], destination)
      else destination.fill(0)
    }
    return this.alive
  }
}
registerProcessor('boohtacord-deepfilter-research', DeepFilterWorklet)
