import { vi } from 'vitest'
import type { VoiceAdmission } from '../voice_session_types'

export function admission(): VoiceAdmission {
  return {
    acquire: vi.fn().mockResolvedValue({ id: 'lease-1', channelId: 'voice-1', transferred: false }),
    credential: vi.fn().mockResolvedValue({ url: 'wss://rtc.example', token: 'temporary', expiresAt: '2026-09-17T12:00:00Z' }),
    release: vi.fn().mockResolvedValue(undefined),
  }
}
