class AggregatePcmMeter extends AudioWorkletProcessor {
  constructor() {
    super(); this.reset()
    this.port.onmessage = event => { if (event.data === 'reset') { this.reset(); this.port.postMessage('reset') } }
  }
  reset() { this.samples = 0; this.square = 0; this.peak = 0; this.nonfinite = 0; this.missingSamples = 0 }
  process(inputs, outputs) {
    const input = inputs[0]?.[0]
    if (input) for (let i = 0; i < input.length; i++) {
      const value = input[i]; this.samples++
      if (!Number.isFinite(value)) this.nonfinite++
      else { this.square += value * value; this.peak = Math.max(this.peak, Math.abs(value)) }
    }
    if (!input) { const count = outputs[0]?.[0]?.length ?? 0; this.samples += count; this.missingSamples += count }
    if (this.samples >= 4800) {
      this.port.postMessage({ samples: this.samples, rms: Math.sqrt(this.square / this.samples), peak: this.peak, nonfinite: this.nonfinite, missingSamples: this.missingSamples })
      this.reset()
    }
    return true
  }
}
registerProcessor('rnnoise-test-meter', AggregatePcmMeter)
