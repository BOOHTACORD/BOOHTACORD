import { describe, expect, it } from 'vitest'
import { shouldRecoverVoiceDisconnect } from './disconnect_recovery_reason'

describe('LiveKit terminal disconnect reasons', () => {
  it('treats SDK exhausted retries and server restart as recoverable', () => {
    expect(shouldRecoverVoiceDisconnect()).toBe(true)
    for (const reason of [3, 6, 7, 8, 9, 14, 15]) expect(shouldRecoverVoiceDisconnect(reason)).toBe(true)
  })

  it('does not auto-rejoin after intentional removal or another-device takeover', () => {
    for (const reason of [0, 1, 2, 4, 5, 10, 11, 12, 13, 16]) {
      expect(shouldRecoverVoiceDisconnect(reason)).toBe(false)
    }
  })
})
