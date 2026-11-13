import { beforeAll, describe, expect, it, vi } from 'vitest'
let Constructor: typeof import('./rnnoise.worklet').RnnoiseAudioWorklet
let resetCalls = 0
const memory = new WebAssembly.Memory({ initial: 1 })
beforeAll(async () => {
  class Base {
    port = { onmessage: undefined as ((event: { data: { type: string } }) => void) | undefined, postMessage: vi.fn() }
  }
  vi.stubGlobal('AudioWorkletProcessor', Base)
  vi.stubGlobal('sampleRate', 48000)
  vi.stubGlobal('registerProcessor', vi.fn())
  vi.stubGlobal('WebAssembly', { Instance: class {
    exports = { memory, _initialize: () => {}, ns_init: () => 1, ns_reset: () => { resetCalls++; new Float32Array(memory.buffer).fill(0) },
      ns_input: () => 0, ns_output: () => 1920, ns_process: () => {
        new Float32Array(memory.buffer, 1920, 480).set(new Float32Array(memory.buffer, 0, 480)); return 0
      } }
  } })
  Constructor = (await import('./rnnoise.worklet')).RnnoiseAudioWorklet
})
function create() { return new Constructor({ processorOptions: { module: {} as WebAssembly.Module } }) }
describe('RNNoise quantum adapter', () => {
  it('retains frame alignment for variable render quanta without double scaling', () => {
    const processor = create(); const received: number[] = []
    for (const length of [128, 64, 256, 32, 480, 128, 256, 96]) {
      const input = new Float32Array(length).fill(0.25), output = new Float32Array(length)
      expect(processor.process([[input]], [[output]])).toBe(true)
      received.push(...output)
    }
    expect(received.slice(0, 480).every(sample => sample === 0)).toBe(true)
    expect(received.slice(480).every(sample => sample === 0.25)).toBe(true)
  })
  it('mute/unmute resets model and discards pre-mute residual PCM', () => {
    const processor = create(), input = new Float32Array(128).fill(0.8)
    for (let i = 0; i < 4; i++) processor.process([[input]], [[new Float32Array(128)]])
    const initial = resetCalls
    processor.port.onmessage?.({ data: { type: 'mute' } } as MessageEvent)
    const muted = new Float32Array(128).fill(1); processor.process([[input]], [[muted]])
    expect([...muted].every(value => value === 0)).toBe(true)
    processor.port.onmessage?.({ data: { type: 'unmute', intent: 42 } } as MessageEvent)
    expect(processor.port.postMessage).toHaveBeenCalledWith({ type: 'unmuted', intent: 42 })
    const output = new Float32Array(960); processor.process([[new Float32Array(960)]], [[output]])
    expect([...output].every(value => value === 0)).toBe(true); expect(resetCalls).toBe(initial + 2)
  })
})
