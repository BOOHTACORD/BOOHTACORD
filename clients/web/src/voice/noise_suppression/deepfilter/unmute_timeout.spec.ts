import { afterEach, expect, it, vi } from 'vitest'
import { DeepFilterTrackProcessor } from './track_processor'

afterEach(() => { vi.useRealTimers(); vi.unstubAllGlobals(); vi.restoreAllMocks() })
it('fails closed when a reset acknowledgement does not arrive within one second', async () => {
  let node: any
  vi.stubGlobal('crypto', { getRandomValues: (bytes: Uint8Array) => bytes })
  vi.stubGlobal('MediaStream', class {})
  vi.stubGlobal('AudioWorkletNode', class {
    port: any = { onmessage: undefined, postMessage: vi.fn((message: any) => {
      if (message.type === 'destroy') queueMicrotask(() => this.port.onmessage?.({ data: { type: 'destroyed' } }))
    }), close: vi.fn() }
    onprocessorerror = null
    constructor() { node = this; queueMicrotask(() => this.port.onmessage?.({ data: { type: 'ready' } })) }
    connect() {} disconnect() {}
  })
  const output = { enabled: true, stop: vi.fn() }, onFailure = vi.fn()
  const context = { sampleRate: 48000, audioWorklet: { addModule: vi.fn() },
    createMediaStreamSource: () => ({ connect: vi.fn(), disconnect: vi.fn() }),
    createMediaStreamDestination: () => ({ stream: { getAudioTracks: () => [output] }, disconnect: vi.fn() }) }
  const processor = new DeepFilterTrackProcessor({ loadAssets: async () => ({ module: {} as WebAssembly.Module, model: new Uint8Array([1]) }), onFailure })
  await processor.init({ track: {}, audioContext: context } as never)
  vi.useFakeTimers()
  const pending = processor.unmute(), rejected = expect(pending).rejects.toThrow('processor timeout')
  await vi.advanceTimersByTimeAsync(1000); await rejected
  expect(output.enabled).toBe(false); expect(onFailure).toHaveBeenCalledWith('processor-error')
  vi.useRealTimers(); await processor.destroy(); expect(node.port.close).toHaveBeenCalledOnce()
})
