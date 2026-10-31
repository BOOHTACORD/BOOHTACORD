import { describe, expect, it, vi } from 'vitest'

import { VoiceParticipantSoundTracker } from './voice_participant_sound_tracker'

describe('voice participant sound tracker', () => {
  it('plays only for participants joining or leaving after the initial roster baseline', () => {
    const play = vi.fn()
    const tracker = new VoiceParticipantSoundTracker(play)

    tracker.seed(['already-here'])
    tracker.participantConnected('already-here')
    tracker.participantConnected('new-member')
    tracker.participantConnected('new-member')
    tracker.participantDisconnected('already-here')
    tracker.participantDisconnected('new-member')
    tracker.participantDisconnected('new-member')

    expect(play.mock.calls).toEqual([['participant-joined'], ['participant-left'], ['participant-left']])
  })

  it('suppresses roster churn during reconnect and seeds the restored roster', () => {
    const play = vi.fn()
    const tracker = new VoiceParticipantSoundTracker(play)

    tracker.seed(['member-a'])
    tracker.pause()
    tracker.participantDisconnected('member-a')
    tracker.participantConnected('member-b')
    tracker.seed(['member-b'])
    tracker.participantConnected('member-b')
    tracker.participantConnected('member-c')

    expect(play.mock.calls).toEqual([['participant-joined']])
  })

  it('does not emit sounds before a connected roster is seeded', () => {
    const play = vi.fn()
    const tracker = new VoiceParticipantSoundTracker(play)

    tracker.participantConnected('early-event')
    tracker.seed(['early-event'])
    tracker.reset()
    tracker.participantConnected('after-reset')

    expect(play).not.toHaveBeenCalled()
  })

  it('ignores server-side screen preview participants', () => {
    const play = vi.fn()
    const tracker = new VoiceParticipantSoundTracker(play)

    tracker.seed(['voice-lease:screen-preview'])
    tracker.participantConnected('voice-lease:screen-preview')
    tracker.participantDisconnected('voice-lease:screen-preview')

    expect(play).not.toHaveBeenCalled()
  })
})
