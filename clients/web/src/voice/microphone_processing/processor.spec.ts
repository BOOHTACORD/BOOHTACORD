import { afterEach, expect, it, vi } from 'vitest'
import type { AudioProcessorOptions } from 'livekit-client'
import { MicrophoneControlsProcessor } from './processor'
import { bindMicrophoneAccount, microphoneMeter, setMicrophoneSettings, setMicrophoneVad } from './runtime'
class Port extends EventTarget {
  onmessage?: (event: MessageEvent) => void
  close = vi.fn()
  messages: unknown[] = []
  postMessage(data: { type: string }) {
    this.messages.push(data)
    if (data.type === 'unmute') queueMicrotask(() => this.dispatchEvent(new MessageEvent('message', { data })))
  }
}
class Node {
  static nodes: Node[] = []
  port = new Port()
  connect = vi.fn()
  disconnect = vi.fn()
  constructor() { Node.nodes.push(this) }
}
afterEach(() => { bindMicrophoneAccount(null); vi.unstubAllGlobals(); Node.nodes = [] })
it('hot updates do not restart capture; composite RNNoise output is enabled and borrowed resources survive', async () => {
  const values = new Map<string, string>()
  vi.stubGlobal('localStorage', { getItem: (k: string) => values.get(k) ?? null, setItem: (k: string, v: string) => values.set(k, v) })
  vi.stubGlobal('AudioWorkletNode', Node)
  vi.stubGlobal('MediaStream', class { constructor(readonly tracks: unknown[]) {} })
  const original = { stop: vi.fn(), enabled: true }
  const innerTrack = { stop: vi.fn(), enabled: false }
  const output = { stop: vi.fn(), enabled: true }
  const context = {
    audioWorklet: { addModule: vi.fn(async () => {}) }, close: vi.fn(),
    createMediaStreamSource: vi.fn(() => ({ connect: vi.fn(), disconnect: vi.fn() })),
    createMediaStreamDestination: () => ({ stream: { getAudioTracks: () => [output] }, disconnect: vi.fn() }),
  }
  const inner = { name: 'rnnoise', init: vi.fn(async () => {}), restart: vi.fn(), destroy: vi.fn(async () => {}),
    mute: vi.fn(() => { innerTrack.enabled = false }), unmute: vi.fn(async () => {}), processedTrack: innerTrack,
  }
  const processor = new MicrophoneControlsProcessor(false, inner as never)
  bindMicrophoneAccount('one')
  await processor.init({ track: original, audioContext: context } as unknown as AudioProcessorOptions)
  await processor.unmute()
  expect(innerTrack.enabled).toBe(true)
  setMicrophoneSettings({ vadThresholdDb: -44, microphoneGainPercent: 175 })
  setMicrophoneVad(false)
  expect(context.audioWorklet.addModule).toHaveBeenCalledTimes(1)
  expect(Node.nodes[0].port.messages).toContainEqual({ type: 'controls', settings: { vadThresholdDb: -44, microphoneGainPercent: 175 }, vad: false, agc: false })
  processor.mute()
  expect(innerTrack.enabled).toBe(false)
  expect(output.enabled).toBe(false)
  await processor.destroy()
  expect(original.stop).not.toHaveBeenCalled()
  expect(context.close).not.toHaveBeenCalled()
  expect(output.stop).toHaveBeenCalled()
  expect(microphoneMeter.value.status).toBe('idle')
})

it('keeps both output tracks disabled when the inner processor fails during unmute', async () => {
  vi.stubGlobal('localStorage', { getItem: () => null, setItem: vi.fn() })
  vi.stubGlobal('AudioWorkletNode', Node)
  vi.stubGlobal('MediaStream', class {})
  const innerTrack = { enabled: false }, output = { enabled: true, stop: vi.fn() }
  const context = { audioWorklet: { addModule: vi.fn(async () => {}) },
    createMediaStreamSource: () => ({ connect: vi.fn(), disconnect: vi.fn() }),
    createMediaStreamDestination: () => ({ stream: { getAudioTracks: () => [output] }, disconnect: vi.fn() }) }
  const inner = { name: 'rnnoise', init: vi.fn(async () => {}), restart: vi.fn(), destroy: vi.fn(async () => {}),
    mute: vi.fn(), unmute: vi.fn(async () => { throw new Error('RNNoise processor failed') }), processedTrack: innerTrack }
  const processor = new MicrophoneControlsProcessor(false, inner as never)
  await processor.init({ track: {}, audioContext: context } as unknown as AudioProcessorOptions)
  await expect(processor.unmute()).rejects.toThrow('RNNoise processor failed')
  expect(innerTrack.enabled).toBe(false); expect(output.enabled).toBe(false)
  await processor.destroy()
})
