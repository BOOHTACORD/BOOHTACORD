import { describe, expect, it } from 'vitest'

import { voiceViewTransitionSound, type VoiceViewSelection } from './voice_view_transition_sound'

describe('voice view transition sound', () => {
  const remote = (id: string): VoiceViewSelection => ({ id, isLocal: false })
  const local = (id: string): VoiceViewSelection => ({ id, isLocal: true })

  it('signals the start and stop of a remote stream view', () => {
    expect(voiceViewTransitionSound(null, remote('stream-a'))).toBe('stream-view-started')
    expect(voiceViewTransitionSound(remote('stream-a'), null)).toBe('stream-view-stopped')
    expect(voiceViewTransitionSound(remote('stream-a'), local('own-stream'))).toBe('stream-view-stopped')
    expect(voiceViewTransitionSound(local('own-stream'), remote('stream-a'))).toBe('stream-view-started')
  })

  it('keeps the view silent when switching remote streams or reselecting the same stream', () => {
    expect(voiceViewTransitionSound(remote('stream-a'), remote('stream-b'))).toBeNull()
    expect(voiceViewTransitionSound(remote('stream-a'), remote('stream-a'))).toBeNull()
    expect(voiceViewTransitionSound(null, local('own-stream'))).toBeNull()
  })
})
