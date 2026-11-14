import { vi } from 'vitest'
import type { LocalAudioTrack } from 'livekit-client'
import { LiveKitMicrophoneAdapter } from '../../src/voice/noise_suppression/microphone_adapter/controller'

export const browser = { noiseSuppressionMode: 'browser', autoGainControl: false, echoCancellation: true } as const
export const rnnoise = { ...browser, noiseSuppressionMode: 'rnnoise' } as const
export const off = { ...browser, noiseSuppressionMode: 'off' } as const

export function fixture() {
  const events: string[] = []
  const captures: Array<{ source: { enabled: boolean }, output: { enabled: boolean } }> = []
  const dependencies = {
    createTrack: vi.fn(async (options: MediaTrackConstraints) => {
      const source = { enabled: true, stop: vi.fn(), getSettings: () => ({ noiseSuppression: options.noiseSuppression === true }) }
      const output = { enabled: false }
      captures.push({ source, output }); events.push(`capture:${options.noiseSuppression}`)
      const track = {
        mediaStreamTrack: source,
        mute: vi.fn(async () => { source.enabled = false; output.enabled = false }),
        unmute: vi.fn(async () => { source.enabled = true }),
        stop: vi.fn(() => { source.enabled = false }),
        // Simulate Chromium accepting but ignoring dynamic NS constraints.
        applyConstraints: vi.fn(async () => undefined),
        restartTrack: vi.fn(async (_options?: MediaTrackConstraints) => undefined),
        setProcessor: vi.fn(async () => { track.mediaStreamTrack = output as typeof source }),
        stopProcessor: vi.fn(async () => { track.mediaStreamTrack = source }),
      }
      return track as unknown as LocalAudioTrack
    }),
    publishTrack: vi.fn(async (track: LocalAudioTrack) => { events.push(`publish:${track.mediaStreamTrack.enabled}`) }),
    unpublishTrack: vi.fn(async () => { events.push('unpublish') }),
    createProcessor: vi.fn((_callbacks: { onFailure(reason: 'overload'): void }) => {
      const output = captures.at(-1)!.output
      return { processedTrack: output, mute: () => { output.enabled = false }, unmute: () => { output.enabled = true }, destroy: vi.fn() } as never
    }),
  }
  return { adapter: new LiveKitMicrophoneAdapter(dependencies), dependencies, events, captures }
}
