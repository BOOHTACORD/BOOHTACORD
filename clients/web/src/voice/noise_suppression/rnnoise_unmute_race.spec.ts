import { afterEach, expect, it, vi } from 'vitest'
import { RnnoiseTrackProcessor } from './rnnoise_track_processor'

afterEach(() => { vi.unstubAllGlobals(); vi.restoreAllMocks() })

async function setup() {
  let node: any
  vi.stubGlobal('window', { isSecureContext: true })
  vi.stubGlobal('AudioContext', class {})
  Object.defineProperty(AudioContext.prototype, 'audioWorklet', { value: {} })
  vi.stubGlobal('MediaStream', class {})
  vi.stubGlobal('AudioWorkletNode', class {
    port: any = { onmessage: undefined, postMessage: vi.fn(), close: vi.fn() }
    onprocessorerror = null
    constructor() { node = this; queueMicrotask(() => this.port.onmessage?.({ data: { type: 'ready' } })) }
    connect() {} disconnect() {}
  })
  const track = { enabled: true, stop: vi.fn(), getSettings: () => ({}) }
  const context = { sampleRate: 48000, audioWorklet: { addModule: vi.fn() },
    createMediaStreamSource: () => ({ connect: vi.fn(), disconnect: vi.fn() }),
    createMediaStreamDestination: () => ({ stream: { getAudioTracks: () => [track] }, disconnect: vi.fn() }) }
  const processor = new RnnoiseTrackProcessor({ loadAssets: async () => ({ module: {} as WebAssembly.Module,
    modelId: 'test', wasmSha256: 'test' }) })
  await processor.init({ kind: 'audio', track, audioContext: context } as never)
  return { node, track, processor }
}

it('cancels an unmute when mute arrives before its acknowledgement', async () => {
  const { node, track, processor } = await setup()
  const pending = processor.unmute(); let settled = false
  void pending.then(() => { settled = true })
  const first = node.port.postMessage.mock.calls.at(-1)[0]
  processor.mute(); await Promise.resolve(); await Promise.resolve()
  expect(settled).toBe(true); expect(track.enabled).toBe(false)
  node.port.onmessage({ data: { type: 'unmuted', intent: first.intent } })
  expect(track.enabled).toBe(false)
  await processor.destroy()
})

it('does not accept an old unmute acknowledgement for a later request', async () => {
  const { node, processor } = await setup()
  const first = processor.unmute()
  const firstIntent = node.port.postMessage.mock.calls.at(-1)[0].intent
  processor.mute(); await first
  const second = processor.unmute(); let settled = false
  void second.then(() => { settled = true })
  const secondIntent = node.port.postMessage.mock.calls.at(-1)[0].intent
  expect(secondIntent).not.toBe(firstIntent)
  node.port.onmessage({ data: { type: 'unmuted', intent: firstIntent } })
  await Promise.resolve(); expect(settled).toBe(false)
  node.port.onmessage({ data: { type: 'unmuted', intent: secondIntent } })
  await second; expect(settled).toBe(true)
  await processor.destroy()
})

it('cancels a pending unmute when the worklet fails', async () => {
  const { node, track, processor } = await setup()
  const pending = processor.unmute()
  node.onprocessorerror()
  await expect(pending).rejects.toThrow('RNNoise processor failed')
  expect(track.enabled).toBe(false)
  expect(processor.runtimeState).toMatchObject({ status: 'error', effectiveMode: 'unknown' })
  await processor.destroy()
})
