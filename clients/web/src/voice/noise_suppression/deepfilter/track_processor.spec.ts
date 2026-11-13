import { afterEach, expect, it, vi } from 'vitest'
import { DeepFilterTrackProcessor } from './track_processor'

afterEach(() => { vi.unstubAllGlobals(); vi.restoreAllMocks() })

async function fixture() {
  let node: any
  vi.stubGlobal('window', { isSecureContext: true })
  vi.stubGlobal('crypto', { getRandomValues: (bytes: Uint8Array) => bytes.fill(9) })
  vi.stubGlobal('MediaStream', class {})
  vi.stubGlobal('AudioWorkletNode', class {
    port: any = { onmessage: undefined, postMessage: vi.fn(), close: vi.fn() }
    onprocessorerror = null
    constructor() {
      node = this
      this.port.postMessage.mockImplementation((message: any) => {
        if (message.type === 'destroy') queueMicrotask(() => this.port.onmessage?.({ data: { type: 'destroyed' } }))
      })
      queueMicrotask(() => this.port.onmessage?.({ data: { type: 'ready' } }))
    }
    connect() {} disconnect() {}
  })
  const output = { enabled: true, stop: vi.fn() }, capture = { stop: vi.fn() }
  const context = { sampleRate: 48000, audioWorklet: { addModule: vi.fn() }, close: vi.fn(),
    createMediaStreamSource: () => ({ connect: vi.fn(), disconnect: vi.fn() }),
    createMediaStreamDestination: () => ({ stream: { getAudioTracks: () => [output] }, disconnect: vi.fn() }) }
  const onFailure = vi.fn(), loadAssets = vi.fn().mockResolvedValue({ module: {}, model: new Uint8Array([1]) })
  const processor = new DeepFilterTrackProcessor({ loadAssets, onFailure })
  await processor.init({ kind: 'audio', track: capture, audioContext: context } as never)
  return { node, output, capture, context, processor, onFailure }
}

it('owns only its derived graph and starts muted until the latest reset is acknowledged', async () => {
  const f = await fixture()
  expect(f.output.enabled).toBe(false)
  const pending = f.processor.unmute(), intent = f.node.port.postMessage.mock.calls.at(-1)[0].intent
  f.node.port.onmessage({ data: { type: 'unmuted', intent } }); await pending
  expect(f.output.enabled).toBe(false) // Caller owns final publication intent.
  await f.processor.destroy()
  expect(f.output.stop).toHaveBeenCalledOnce()
  expect(f.capture.stop).not.toHaveBeenCalled(); expect(f.context.close).not.toHaveBeenCalled()
})

it('keeps the port open until the worklet confirms disposal', async () => {
  const f = await fixture()
  f.node.port.postMessage.mockImplementation(() => {})
  const pending = f.processor.destroy(); let done = false
  void pending.then(() => { done = true })
  await Promise.resolve()
  expect(f.output.stop).toHaveBeenCalledOnce(); expect(f.node.port.close).not.toHaveBeenCalled()
  expect(done).toBe(false)
  f.node.port.onmessage({ data: { type: 'destroyed' } }); await pending
  expect(f.node.port.close).toHaveBeenCalledOnce()
})

it('cancels a new initialization while a previous disposal is pending', async () => {
  const f = await fixture()
  f.node.port.postMessage.mockImplementation(() => {})
  const disposal = f.processor.destroy()
  const init = f.processor.init({ track: {}, audioContext: { sampleRate: 48000 } } as never)
  const secondDisposal = f.processor.destroy()
  f.node.port.onmessage({ data: { type: 'destroyed' } })
  await Promise.all([disposal, secondDisposal, init])
  expect(f.processor.processedTrack).toBeUndefined(); expect(f.onFailure).not.toHaveBeenCalled()
})

it('closes the port and reports disposal timeout without leaving capture enabled', async () => {
  const f = await fixture()
  vi.useFakeTimers()
  try {
    f.node.port.postMessage.mockImplementation(() => {})
    const disposal = f.processor.destroy()
    const rejected = expect(disposal).rejects.toThrow('processor disposal timeout')
    await vi.advanceTimersByTimeAsync(1000); await rejected
    expect(f.output.stop).toHaveBeenCalledOnce(); expect(f.node.port.close).toHaveBeenCalledOnce()
  } finally { vi.useRealTimers() }
})

it('ignores stale acknowledgements after mute and fails closed on processor error', async () => {
  const f = await fixture(), first = f.processor.unmute()
  const intent = f.node.port.postMessage.mock.calls.at(-1)[0].intent
  f.processor.mute(); await first
  const second = f.processor.unmute()
  f.node.port.onmessage({ data: { type: 'unmuted', intent } })
  f.node.port.onmessage({ data: { type: 'error', reason: 'overload' } })
  await expect(second).rejects.toThrow('processor failed')
  expect(f.output.enabled).toBe(false); expect(f.onFailure).toHaveBeenCalledWith('overload')
  await f.processor.destroy()
})

it('does not load a model or connect audio when the context rate is unsupported', async () => {
  const loadAssets = vi.fn(), onFailure = vi.fn()
  const processor = new DeepFilterTrackProcessor({ loadAssets, onFailure })
  await expect(processor.init({ track: {}, audioContext: { sampleRate: 44100 } } as never)).rejects.toThrow('48 kHz')
  expect(loadAssets).not.toHaveBeenCalled(); expect(processor.processedTrack).toBeUndefined()
  expect(onFailure).toHaveBeenCalledWith('sample-rate')
})

it('reports unavailable model assets without creating a graph', async () => {
  const onFailure = vi.fn(), loadAssets = vi.fn().mockRejectedValue(new Error('unavailable'))
  const processor = new DeepFilterTrackProcessor({ loadAssets, onFailure })
  await expect(processor.init({ track: {}, audioContext: { sampleRate: 48000 } } as never)).rejects.toThrow('unavailable')
  expect(onFailure).toHaveBeenCalledWith('asset-load')
  expect(processor.processedTrack).toBeUndefined()
})

it('does not construct a stale graph when destroyed during asset loading', async () => {
  let resolve!: (value: any) => void
  const pendingAssets = new Promise<any>(done => { resolve = done })
  const addModule = vi.fn(), onFailure = vi.fn()
  const processor = new DeepFilterTrackProcessor({ loadAssets: () => pendingAssets, onFailure })
  const init = processor.init({ track: {}, audioContext: { sampleRate: 48000, audioWorklet: { addModule } } } as never)
  await processor.destroy()
  const settled = await Promise.race([init.then(() => true), new Promise<boolean>(done => setTimeout(() => done(false), 30))])
  expect(settled).toBe(true)
  resolve({ module: {}, model: new Uint8Array([1]) }); await init
  expect(addModule).not.toHaveBeenCalled(); expect(processor.processedTrack).toBeUndefined()
  expect(onFailure).not.toHaveBeenCalled()
})
