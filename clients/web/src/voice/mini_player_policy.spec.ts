import { describe, expect, it } from 'vitest'

import { miniPlayerVisible, screenViewerMounted } from './mini_player_policy'

describe('mini player policy', () => {
  it('keeps the selected stream mounted after leaving its voice channel while connected', () => {
    expect(screenViewerMounted(false, 'stream-a', 'voice-a')).toBe(true)
    expect(miniPlayerVisible(false, 'stream-a', 'voice-a')).toBe(true)
    expect(screenViewerMounted(true, 'stream-a', 'voice-a')).toBe(true)
    expect(miniPlayerVisible(true, 'stream-a', 'voice-a')).toBe(false)
  })

  it('closes on leave, revocation or ended selection', () => {
    expect(screenViewerMounted(false, null, 'voice-a')).toBe(false)
    expect(screenViewerMounted(false, 'stream-a', null)).toBe(false)
    expect(miniPlayerVisible(false, null, 'voice-a')).toBe(false)
  })
})
