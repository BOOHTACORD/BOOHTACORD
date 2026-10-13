import { afterEach, expect, it, vi } from 'vitest'
import { VoiceScreenSession, type ScreenVoiceSession } from '../../voice_screen_session'
import type { VoiceRoom } from '../../livekit_gateway'
import { setup } from '../../screen_publisher/adapter_fixture'
import { calibration, window } from './fixture'

afterEach(() => vi.useRealTimers())
it('real VoiceScreenSession diagnostic ingress applies classified decisions and updates effective metadata', async () => {
  vi.useFakeTimers()
  const f = setup(), metadata = vi.fn(async () => {})
  const room = { screenPublisher: f.port, readScreenDiagnostics: () => f.port.diagnostics(), publishScreenProfileMetadata: metadata } as unknown as VoiceRoom
  const current: ScreenVoiceSession = { room, screenProfile: null }
  let at = 1000
  const session = new VoiceScreenSession(() => current, { enabled: true, calibration, now: () => at,
    readWindow: (_diagnostics, context) => window(at, context.publicationGeneration) })
  await session.startScreen('P1080_60')
  await session.readScreenDiagnostics(); at = 2000
  expect((await session.readScreenDiagnostics()).adaptationReason).toBe('downgrade-pressure')
  expect(f.port.capture).toHaveBeenCalledTimes(1)
  expect(current.screenProfile).toBe('P720_60')
  expect(metadata).toHaveBeenLastCalledWith('P720_60', 'motion')
  session.cancel()
})
it('default session reads diagnostics without running a classifier or changing media', async () => {
  vi.useFakeTimers()
  const f = setup(), classifier = vi.fn()
  const room = { screenPublisher: f.port, readScreenDiagnostics: () => f.port.diagnostics() } as unknown as VoiceRoom
  const current: ScreenVoiceSession = { room, screenProfile: null }
  const session = new VoiceScreenSession(() => current, { calibration, readWindow: classifier })
  await session.startScreen('P1080_60')
  await session.readScreenDiagnostics(); await session.readScreenDiagnostics()
  expect(classifier).not.toHaveBeenCalled()
  expect(f.port.capture).not.toHaveBeenCalled()
  session.cancel()
})
