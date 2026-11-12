class AggregatePcmMeter extends AudioWorkletProcessor {
  constructor() {
    super(); this.reset()
    this.port.onmessage = event => { if (event.data === 'reset') { this.reset(); this.port.postMessage('reset') } }
  }
  reset() { this.samples = 0; this.square = 0; this.peak = 0; this.nonfinite = 0 }
  process(inputs) {
    const input = inputs[0]?.[0]
    if (input) for (let i = 0; i < input.length; i++) {
      const value = input[i]; this.samples++
      if (!Number.isFinite(value)) this.nonfinite++
      else { this.square += value * value; this.peak = Math.max(this.peak, Math.abs(value)) }
    }
    if (this.samples >= 4800) {
      this.port.postMessage({ samples: this.samples, rms: Math.sqrt(this.square / this.samples), peak: this.peak, nonfinite: this.nonfinite })
      this.reset()
    }
    return true
  }
}
registerProcessor('rnnoise-test-meter', AggregatePcmMeter)
