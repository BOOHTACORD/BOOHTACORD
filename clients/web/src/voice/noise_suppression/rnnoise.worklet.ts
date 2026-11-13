import { SampleRingBuffer, toPcm16Float, fromPcm16Float } from './ring_buffer'
// AudioWorklet globals are intentionally local; the main bundle uses DOM types.
declare const sampleRate: number
declare abstract class AudioWorkletProcessor {
  readonly port: MessagePort
  constructor(options?: unknown)
}
declare function registerProcessor(name: string, constructor: typeof AudioWorkletProcessor): void
interface DspExports extends WebAssembly.Exports {
  memory: WebAssembly.Memory
  _initialize(): void; ns_init(): number; ns_reset(): void; ns_input(): number; ns_output(): number; ns_process(): number
}
/** Scalar 48 kHz mono. All DSP storage is allocated in construction. */
export class RnnoiseAudioWorklet extends AudioWorkletProcessor {
  private readonly input = new SampleRingBuffer(1920)
  private readonly output = new SampleRingBuffer(1920)
  private readonly dsp: DspExports
  private readonly frameIn: Float32Array
  private readonly frameOut: Float32Array
  private enabled = true
  private alive = true
  private readonly health = { type: 'health', processedFrames: 0, fifoUnderruns: 0, fifoOverruns: 0, processorErrors: 0 }
  constructor(options?: { processorOptions?: { module: WebAssembly.Module } }) {
    super(options)
    if (sampleRate !== 48000 || !options?.processorOptions?.module) throw new Error('RNNoise requires 48 kHz')
    this.dsp = new WebAssembly.Instance(options.processorOptions.module, {}).exports as DspExports
    this.dsp._initialize()
    if (this.dsp.ns_init() !== 1) throw new Error('RNNoise state initialization failed')
    this.frameIn = new Float32Array(this.dsp.memory.buffer, this.dsp.ns_input(), 480)
    this.frameOut = new Float32Array(this.dsp.memory.buffer, this.dsp.ns_output(), 480)
    this.reset()
    this.port.onmessage = event => {
      if (event.data.type === 'mute' || event.data.type === 'unmute' || event.data.type === 'reset') {
        this.reset()
        if (event.data.type !== 'reset') this.enabled = event.data.type === 'unmute'
        if (event.data.type === 'unmute') this.port.postMessage({ type: 'unmuted', intent: event.data.intent })
      } else if (event.data.type === 'destroy') { this.enabled = false; this.alive = false; this.reset() }
    }
    this.port.postMessage({ type: 'ready', contextSampleRate: sampleRate })
  }
  private reset(): void {
    this.input.clear(); this.output.clear(); this.dsp.ns_reset()
    // Fixed one-frame scheduling delay prevents quantum/frame remainder glitches.
    for (let i = 0; i < 480; i++) this.output.push(0)
  }
  process(inputs: Float32Array[][], outputs: Float32Array[][]): boolean {
    const destination = outputs[0]?.[0]
    if (!destination) return this.alive
    destination.fill(0)
    if (!this.enabled || !this.alive) return this.alive
    const source = inputs[0]?.[0]
    try {
      if (source) {
        for (let offset = 0; offset < source.length; offset++) {
          if (!this.input.push(toPcm16Float(source[offset]))) {
            this.health.fifoOverruns++; this.reset(); this.port.postMessage(this.health); return this.alive
          }
          if (this.input.size === 480) {
            for (let i = 0; i < 480; i++) this.frameIn[i] = this.input.shift() ?? 0
            this.dsp.ns_process()
            for (let i = 0; i < 480; i++) {
              if (!this.output.push(fromPcm16Float(this.frameOut[i]))) {
                this.health.fifoOverruns++; this.reset(); this.port.postMessage(this.health); return this.alive
              }
            }
            this.health.processedFrames++
            // Reused envelope, bounded aggregate updates; no PCM ever leaves worklet.
            if (this.health.processedFrames % 100 === 0) this.port.postMessage(this.health)
          }
        }
      }
      for (let i = 0; i < destination.length; i++) {
        const sample = this.output.shift()
        if (sample === undefined) this.health.fifoUnderruns++
        destination[i] = sample ?? 0
      }
    } catch {
      this.enabled = false; this.health.processorErrors++; this.port.postMessage(this.health)
    }
    return this.alive
  }
}
registerProcessor('boohtacord-rnnoise', RnnoiseAudioWorklet)
