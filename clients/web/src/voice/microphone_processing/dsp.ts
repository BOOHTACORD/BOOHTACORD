import type { MicrophoneSettings } from './settings'
/** Allocation-free callback; input level is measured before software gain. */
export class MicrophoneDsp {
  private threshold = -50
  private targetGain = 1
  private gain = 1
  private vad = true
  private hold = 0
  private gateGain = 0
  private index = 0
  private readonly delay: Float32Array
  gateOpen = false
  levelDb = -90
  clipping = false
  constructor(private readonly rate: number) { this.delay = new Float32Array(Math.max(1, Math.round(rate * .02))) }
  configure(settings: MicrophoneSettings, vad: boolean, agc: boolean): void {
    if (vad !== this.vad) this.reset()
    this.threshold = settings.vadThresholdDb
    this.targetGain = agc ? 1 : settings.microphoneGainPercent / 100
    if (this.targetGain === 0) this.gain = 0
    this.vad = vad
  }
  reset(): void { this.delay.fill(0); this.index = 0; this.hold = 0; this.gateOpen = false; this.gateGain = 0 }
  process(input: Float32Array, output: Float32Array): void {
    let energy = 0
    for (let i = 0; i < input.length; i++) energy += Number.isFinite(input[i]) ? input[i] * input[i] : 0
    this.levelDb = Math.max(-90, 10 * Math.log10(Math.max(1e-9, energy / Math.max(1, input.length))))
    if (this.levelDb >= (this.gateOpen ? this.threshold - 6 : this.threshold)) {
      this.gateOpen = true
      this.hold = Math.round(this.rate * .2)
    } else { this.hold = Math.max(0, this.hold - input.length); if (!this.hold) this.gateOpen = false }
    this.clipping = false
    const step = 1 / Math.max(1, this.rate * .01)
    const gateStep = this.gateOpen ? 1 / Math.max(1, this.rate * .005) : -1 / Math.max(1, this.rate * .05)
    for (let i = 0; i < output.length; i++) {
      const sample = Number.isFinite(input[i]) ? input[i] : 0
      const delayed = this.delay[this.index]
      this.delay[this.index] = sample
      this.index = (this.index + 1) % this.delay.length
      this.gain += Math.max(-step, Math.min(step, this.targetGain - this.gain))
      if (this.vad) this.gateGain = Math.max(0, Math.min(1, this.gateGain + gateStep))
      const value = (this.vad ? delayed * this.gateGain : sample) * this.gain
      this.clipping ||= Math.abs(value) > 1
      output[i] = Math.max(-1, Math.min(1, value))
    }
  }
}
