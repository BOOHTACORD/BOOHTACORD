import { afterEach, describe, expect, it, vi } from 'vitest'
import { LiveKitScreenRegistry } from './livekit_screen_registry'

afterEach(() => vi.unstubAllEnvs())

describe('screen descriptor rollout', () => {
  it('uses legacy labels when descriptor metadata is disabled independently', () => {
    vi.stubEnv('VITE_SCREEN_SHARE_DESCRIPTOR_V1', 'false')
    const registry = new LiveKitScreenRegistry('https://app.example.test', 'voice:channel-a')
    registry.refresh([{
      accountId: '11111111-1111-4111-8111-111111111111',
      attributes: { 'boohtacord.screen-share.v1': '{"unsupported":true}' },
      identity: 'lease-a',
      video: { setSubscribed: vi.fn(), trackName: 'screenshare-1080p-30fps' },
    }], null)

    expect(registry.streams()[0]).toMatchObject({ targetProfile: '1080p · 30 FPS', profileSource: 'legacy-track-name' })
  })
})
