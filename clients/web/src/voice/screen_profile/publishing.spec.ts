import { describe, expect, it, vi } from 'vitest'
import type { LocalVideoTrack } from 'livekit-client'
import type { ScreenDiagnostics } from '../screen_diagnostics'
import type { VoiceRoom } from '../livekit_gateway'
import { VoiceScreenSession } from '../voice_screen_session'
import type { ScreenPublisherPort } from '../screen_publisher/types'

function setup() {
  const track = { id: 'screen' } as unknown as LocalVideoTrack, calls: string[] = []
  let published: LocalVideoTrack | undefined, generation = 0
  let ended: () => void = () => {}
  const diagnostics: ScreenDiagnostics = { audioTrack: 'PRESENT', connectionQuality: 'GOOD', measured: null, source: 'ACTIVE' }
  const port: ScreenPublisherPort<LocalVideoTrack> = {
    generation: () => generation, isLive: () => true, currentTrack: () => published,
    start: vi.fn(async () => { calls.push('start'); published = track; generation++; return track }),
    capture: vi.fn(async () => { calls.push('capture') }),
    unpublish: vi.fn(async (_track, stopCapture) => { calls.push(`unpublish:${stopCapture}`); published = undefined; generation++ }),
    publish: vi.fn(async () => { calls.push('publish'); published = track; generation++ }),
    stop: vi.fn(async () => { calls.push('stop'); published = undefined; generation++ }),
    diagnostics: vi.fn(async () => diagnostics), repair: vi.fn(async () => true),
    onEnded: vi.fn(listener => { ended = listener; return () => {} }),
  }
  const room = {
    screenPublisher: port, readScreenDiagnostics: vi.fn(async () => diagnostics), adoptScreenProfile: vi.fn(),
    publishScreenProfileMetadata: vi.fn(async () => undefined), clearScreenProfileMetadata: vi.fn(async () => undefined),
    stopScreenProfileChecks: vi.fn(),
  } as unknown as VoiceRoom
  const active = { room, screenProfile: null as import('../screen_profile/policy').ScreenProfile | null }
  const session = new VoiceScreenSession(() => active)
  return { session, room, port, calls, active, track, diagnostics, end: () => { published = undefined; generation++; ended() } }
}

describe('screen session uses the operation adapter', () => {
  it('routes start, profile update and stop through one publisher boundary', async () => {
    const f = setup(); await f.session.startScreen('P1080_30'); await f.session.updateScreenProfile('P720_30'); await f.session.stopScreen()
    expect(f.calls).toEqual(['start', 'capture', 'unpublish:false', 'publish', 'stop'])
    expect(f.room.adoptScreenProfile).toHaveBeenCalledWith('P720_30')
    expect(f.active.screenProfile).toBeNull()
  })
  it('keeps an explicit diagnostics read side-effect free even when drift is present', async () => {
    const f = setup(); await f.session.startScreen('P1080_30')
    f.room.readScreenDiagnostics = vi.fn(async () => ({ ...f.diagnostics, profileCheck: { status: 'drift' as const, reason: 'configuration' as const, attempts: 0 } }))
    await expect(f.session.readScreenDiagnostics()).resolves.toMatchObject({ profileCheck: { status: 'drift' } })
    expect(f.port.repair).not.toHaveBeenCalled(); expect(f.port.publish).not.toHaveBeenCalled()
    await f.session.stopScreen()
  })
  it('refreshes metadata after a failed profile update restores the previous publication', async () => {
    const f = setup(); await f.session.startScreen('P1080_30')
    vi.mocked(f.port.publish).mockRejectedValueOnce(new Error('temporary publish failure'))
    await expect(f.session.updateScreenProfile('P720_30')).rejects.toThrow('прежняя конфигурация восстановлена')
    expect(f.active.screenProfile).toBe('P1080_30')
    expect(f.room.publishScreenProfileMetadata).toHaveBeenNthCalledWith(2, 'P1080_30', 'motion')
    expect(f.port.publish).toHaveBeenCalledTimes(2)
  })
  it('refreshes metadata after the repair watchdog repairs a drifted publication', async () => {
    vi.useFakeTimers()
    try {
      const f = setup(); await f.session.startScreen('P1080_30')
      f.room.readScreenDiagnostics = vi.fn(async () => ({
        ...f.diagnostics, profileCheck: { status: 'drift' as const, reason: 'configuration' as const, attempts: 0 },
      }))
      await vi.advanceTimersByTimeAsync(5000)
      expect(f.port.repair).toHaveBeenCalledWith(f.track, 'P1080_30', expect.any(Function))
      expect(f.room.publishScreenProfileMetadata).toHaveBeenNthCalledWith(2, 'P1080_30', 'motion')
      await f.session.stopScreen()
    } finally { vi.useRealTimers() }
  })
  it('cancels the active adapter and cleans the screen publication after an SDK ended event', async () => {
    const f = setup(); await f.session.startScreen('P1080_30'); f.end()
    await vi.waitFor(() => expect(f.port.stop).toHaveBeenCalledWith(f.track))
    expect(f.active.screenProfile).toBeNull()
  })
  it('notifies screen controls when a browser-ended event arrives before a profile is recorded', async () => {
    const f = setup(), ended = vi.fn()
    f.session.onScreenEnded(ended)
    await f.session.startScreen('P1080_30')
    f.active.screenProfile = null

    f.end()

    expect(ended).toHaveBeenCalledOnce()
    await vi.waitFor(() => expect(f.port.stop).toHaveBeenCalledWith(f.track))
  })
})
