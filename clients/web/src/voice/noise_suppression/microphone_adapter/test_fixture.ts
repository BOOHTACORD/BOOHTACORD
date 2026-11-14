import { vi } from 'vitest'
import type { LocalAudioTrack } from 'livekit-client'
import { LiveKitMicrophoneAdapter } from './controller'
import type { AudioProcessingOptions } from '../types'

export function fixture() {
  let reported = true
  const source = { enabled: true, stop: vi.fn(), getSettings: () => ({ noiseSuppression: reported }) }
  const output = { enabled: true }
  const processor = { processedTrack: output, name: 'test', mute: vi.fn(() => { output.enabled = false }), unmute: vi.fn(), destroy: vi.fn(), init: vi.fn() }
  const track = { mediaStreamTrack: source, mute: vi.fn(async () => { source.enabled = false }),
    unmute: vi.fn(async () => { source.enabled = true }), stop: vi.fn(),
    applyConstraints: vi.fn(async (constraints: MediaTrackConstraints) => { reported = constraints.noiseSuppression === true }), restartTrack: vi.fn(async () => {}),
    setProcessor: vi.fn(async () => { track.mediaStreamTrack = output as typeof source }),
    stopProcessor: vi.fn(async () => { track.mediaStreamTrack = source }) }
  const dependencies = { createTrack: vi.fn(async () => track as unknown as LocalAudioTrack),
    publishTrack: vi.fn(async () => {}), unpublishTrack: vi.fn(async () => {}),
    createProcessor: vi.fn((_callbacks: unknown, _options?: AudioProcessingOptions) => processor as never) }
  return { adapter: new LiveKitMicrophoneAdapter(dependencies), dependencies, track, processor, source, output }
}
